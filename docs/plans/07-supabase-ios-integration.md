# Supabase iOS integration plan

Status: implemented on September 13, 2026 (§1–§4), with the review changes
recorded in §6. Verified by unsigned Debug and Release builds for generic iOS;
the live checks in §5 still need a run from the app. Extracted from plan 04 on
September 13, 2026. Content import moved to [plan 09](09-content-import.md).

Integrate the Swift app with the existing self-hosted Supabase API. This work
is independent of the [repository migration](04-supabase-migration.md); that
migration can finish before the iOS client is implemented. Server schema
changes are outside this plan.

## 1. Client configuration

The iOS app needs `SUPABASE_URL` and the anon key. The anon key is public by
design — row-level security protects database access, with the existing
policies allowing `select` on `status = 'published'` for `anon` and
`authenticated`, all writes to `service_role`, and storage insert/select/delete
gated on `(storage.foldername(name))[1] = auth.uid()::text`. It ships inside
the IPA regardless. The goal is to keep it out of scattered Swift source, not
to hide it. The `ugc-*` buckets are intentionally public: anyone with an asset
URL can download it. The ownership policies restrict uploads, listing, and
deletion; they do not make public downloads private.

Both values are two constants in `DreamApp/Config/AppConfiguration.swift`:

```swift
nonisolated enum AppConfiguration {
    static let supabaseURL = URL(string: "https://dreamproject-supabase-7b2379-187-77-132-199.sslip.io")!
    static let supabaseAnonKey = "<the anon key; role claim \"anon\">"
}
```

There is no runtime environment on iOS. Expo's `EXPO_PUBLIC_*` values were
inlined at bundle time, and the Xcode equivalent is a build setting: an
xcconfig feeding Info.plist. That route only pays off when Debug and Release
need different values, such as a staging instance. With one self-hosted
instance and public values, the constants do the same job without a
project-file reference, Info.plist keys, or a `Bundle.main` lookup. If a
staging stack appears, wrap the two values in `#if DEBUG` first; bring
xcconfig back only when that is not enough.

The `service_role` key must never reach anything the app can read; it stays
in the Dokploy environment. The deployment scripts do not need it in
`server/.env.local`. No ignored local config, example copy, or manual setup
step is needed.

## 2. Client and anonymous session

[`supabase/supabase-swift`](https://github.com/supabase/supabase-swift) is
added through SPM beside GRDB, pinned up to the next major from 2.55.2, linked
into the app target only. `AppDependencies` owns one shared client, created by
`SupabaseClient.live()` in `Infrastructure/Supabase/SupabaseSession.swift`
with default options: the SDK persists the session in the Keychain and
refreshes tokens itself.

Function calls do not need a user session. The self-hosted router accepts any
JWT signed with the project secret, which includes the anon key, and none of
the functions read the user. The SDK sends the user's access token when a
session exists and the anon key otherwise. Only storage uploads need the user.
Nothing in the app waits on session initialization except an upload.

Nothing runs at startup. The first upload calls `SupabaseSession.session()`,
which restores the persisted session or signs in anonymously on demand. Local
GRDB screens never touch it.

Supabase anonymous sign-in creates a real user with a UUID and
`is_anonymous = true`. That user ID owns uploads; there is no separate
temporary-account system, no fake login credentials, and no additional user
ID. The UUID is stable across refreshes. Losing the session credentials leaves
no independent account-recovery method. A future account feature can link a
login identity to the existing anonymous user; login UI and merging with an
existing account are outside this plan.

The `SupabaseSession` actor is limited to session coordination:

- `session()` returns `auth.session`, which the SDK refreshes when expired.
  Only `AuthError.sessionMissing` triggers `signInAnonymously()`; connectivity
  and refresh failures propagate, and a later call retries. No separate token
  store or refresh timer.
- Concurrent callers share one in-progress task, cleared when it finishes.
  There is no permanent "ready" result; a later call goes back through the SDK.
- `userID()` exposes the owner prefix for uploads.
- Networking stays out of views and SDK details inside the data and
  infrastructure layers. There is no generic API manager or pass-through
  service layer.

The Keychain entry outlives the app: reinstalling on a device keeps the same
anonymous user, so uploads keep their owner. It also means a "fresh install"
check needs a sign-out or a simulator reset first.

## 3. Function payloads

`Features/AddCard/Data/CardTitleGeneration.swift` holds the request and
response structs next to their consumer and matches the backend's wire format
from `generate-text/workflows/card-title.ts`. No shared TypeScript package or
code generator is required.

- `CardTitleInput` carries `inputText`, `learningLanguageCode`,
  `nativeLanguage`, `nativeWritingSystem`, and `userKnowledgeLevel`. A
  convenience initializer builds `nativeWritingSystem` as
  `"\(promptName) (\(writing.standard))"` from the [plan 06](06-language-config.md)
  catalog, `nativeLanguage` from `NativeLanguage.name`, and
  `userKnowledgeLevel` from the `KnowledgeLevel` raw value, as the old app did.
- The envelope is `{ "type": "card-title", "input": … }` in and
  `{ "data": { "titleVariants": [...] }, "metadata": … }` out. Metadata is
  ignored. `CardTitleVariant` reuses `SentenceType` from Core; `contentType`
  and `tone` are small local enums.
- `CardTitleGenerationError` raw values are the server's `{ "code": … }`
  values plus the transport codes, the same set `docs/design.md` maps to alert
  text. HTTP failures prefer the body code, then fall back on status: 401 and
  403 to `unauthorized`, 404 to `not_found`, 408 and 504 to `timeout`, 429 to
  `rate_limited`, 5xx to `server_failed`. Relay errors are `server_failed`,
  decoding failures `invalid_response`, a URL timeout `timeout`, and any other
  transport error `network_failed`.
- Each invocation passes a 120-second `timeoutInterval`, as the old client
  did, because generation can exceed URLSession's 60-second default. The
  decoder is an explicit `JSONDecoder()` so the SDK's default cannot change
  key handling.
- `CardTitleGenerating` is the feature's protocol so screens and previews can
  substitute the network, per `architecture.md`. The live `CardTitleGeneration`
  takes the shared client; features build it from `AppDependencies.supabase`.

The image and audio functions return `{ contentType, base64, metadata }` with
their own error codes. Their Swift payloads follow the same pattern when the
generation screen lands; decoding base64 on the client is the current contract.

## 4. Uploads

`Infrastructure/Media/MediaUploader.swift` uploads into the `ugc-photos` and
`ugc-audio` buckets under `{auth.uid()}/{uuid}.{ext}` as the storage policies
require, using the user's session and never the service-role key.

- `MediaKind` selects the bucket and maps a MIME type to an extension. The map
  equals each bucket's `allowed_mime_types`; anything else is `invalidFile`.
- The path's first segment must be lowercase: the policy compares it with
  `auth.uid()::text`, which Postgres renders in lowercase, while Swift's
  `uuidString` is uppercase.
- `cacheControl` is one year and `upsert` is off, matching the old client.
- `UploadedMedia.storagePath` is `bucket/path`, the `storagePath` an asset
  stores. Errors are `unauthenticated`, `invalidFile`, and `uploadFailed`.
- `MediaUploading` is the substitutable contract. `AppDependencies` owns the
  live `MediaUploader` because more than one feature will upload.

Importing published server content into GRDB is a different concern with no
caller yet and is planned separately in [plan 09](09-content-import.md).

## 5. Verification

Done on September 13, 2026:

- Unsigned Debug and Release builds for generic iOS. `Package.resolved` pins
  supabase-swift 2.55.2.
- The anon key's JWT payload has `"role": "anon"`, not `service_role`.

Still to run from the app (needs a device or the simulator; ask first):

- An existing session is reused across launches, and a fresh installation
  (after sign-out or a simulator reset, because the Keychain persists) obtains
  an anonymous session.
- Concurrent upload requests share one initialization, and an offline or
  failed refresh neither creates a new anonymous user nor blocks local GRDB
  screens.
- One `generate-text` call with a representative `card-title` payload decodes;
  an invalid payload maps to `invalid_request`.
- One media upload lands under the current user's prefix; a second user's
  prefix is rejected by the policy.
- Confirm anonymous sign-in is enabled on the live GoTrue. `config.toml` only
  configures the local CLI stack; the Dokploy instance reads its own auth
  environment. The old app relied on it, so it is expected to be on.

Do not add tests without approval or open the iPhone simulator without asking.
No commit was made and nothing was deployed.

## 6. Review changes

Differences from the plan as first written, decided during review on
September 13, 2026:

1. Function calls are documented as session-free, and no session is created
   at startup: the first upload creates it on demand.
2. Section 4 was split. Uploads stayed here; the content import adapter moved
   to plan 09 because it has no trigger, no query, and no caller yet, the same
   state as the seed loader in plan 05.
3. The 120-second per-invocation timeout, the explicit decoder, and the error
   envelope mapping were added to §3.
4. The lowercase owner prefix requirement was added to §4.
5. Verification targets the live GoTrue for the anonymous-sign-in flag and
   accounts for the Keychain surviving a reinstall.
6. Feature and infrastructure protocols (`CardTitleGenerating`,
   `MediaUploading`) were added up front, per the architecture rule for
   network dependencies.
7. The xcconfig and Info.plist route was implemented first and then replaced
   by the two constants in §1: with one instance, nothing needed a
   per-configuration value. While it existed, Xcode 26 stripped the `//` in
   `https:$()//host` before substitution; `https:/$()/host` was the working
   form.

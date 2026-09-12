# Supabase iOS integration plan

Status: planned, not implemented. Extracted from plan 04 on September 13, 2026.

Integrate the Swift app with the existing self-hosted Supabase API. This work
is independent of the [repository migration](04-supabase-migration.md); that
migration can finish before the iOS client is implemented. Server schema
changes are outside this plan.

## 1. Client configuration

The iOS app needs `SUPABASE_URL` and the anon key. The anon key is public by
design — row-level security protects database access, with the existing
policies allowing `select` on `status = 'published'` for `anon` and
`authenticated`, all writes to `service_role`, and storage insert/select/delete
gated on `(storage.foldername(name))[1] = auth.uid()`. It ships inside the IPA
regardless. The goal is to keep it out of scattered Swift source, not to hide it.
The `ugc-*` buckets are intentionally public: anyone with an asset URL can
download it. The ownership policies restrict uploads, listing, and deletion;
they do not make public downloads private.

The Xcode equivalent of `EXPO_PUBLIC_*` is an xcconfig feeding Info.plist:

```xcconfig
// apps/ios/Config/Supabase.xcconfig (committed)
// Illustrative values; use the actual public URL and anon key when implementing.
// xcconfig treats // as a comment, so break the scheme separator:
SUPABASE_URL = https:$()//supabase.example.com
SUPABASE_ANON_KEY = your-anon-key
```

```swift
// apps/ios/DreamApp/Config/AppConfiguration.swift
import Foundation

nonisolated enum AppConfiguration {
    static let supabaseURL = url(for: "SUPABASE_URL")
    static let supabaseAnonKey = string(for: "SUPABASE_ANON_KEY")

    private static func string(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else { fatalError("Missing \(key). Check Config/Supabase.xcconfig and Info.plist build settings.") }
        return value
    }

    private static func url(for key: String) -> URL {
        guard let url = URL(string: string(for: key)) else { fatalError("\(key) is not a URL") }
        return url
    }
}
```

`Config/AppConfiguration.swift` is the slot already reserved in
`architecture.md`. The `service_role` key must never reach anything the app can
read; it stays in the Dokploy environment. The deployment scripts do not need
it in `server/.env.local`.

Commit `apps/ios/Config/Supabase.xcconfig` with the actual public URL and anon
key. No ignored local config, example copy, or manual setup step is needed.
Wire the xcconfig into the app's Debug and Release build configurations
and add `SUPABASE_URL` and `SUPABASE_ANON_KEY` substitutions to the app's
Info.plist configuration. Only public client configuration belongs in this
file; server credentials remain in the deployment environment.

## 2. Client and anonymous session

Add [`supabase/supabase-swift`](https://github.com/supabase/supabase-swift)
through SPM beside GRDB. Own one shared client in `AppDependencies`, with the
client setup and small session wrapper in `Infrastructure/Supabase/`.
Initialize the session asynchronously at app startup: reuse the persisted
session, or sign in anonymously if no session exists. Session creation does
not need to be deferred until the first upload. Local GRDB screens must remain
usable while authentication is pending or the device is offline.

Supabase anonymous sign-in already creates a real user with a UUID and
`is_anonymous = true`. Use that user ID for upload ownership; do not build a
separate temporary-account system, generate fake login credentials, or invent
an additional user ID. The UUID remains stable across session refreshes.
Losing the session credentials leaves no independent account-recovery method.
A future account feature can link a login identity to the existing anonymous
user; login UI and merging with an existing account are outside this plan.

Keep the wrapper limited to session coordination:

- Let the SDK handle Keychain persistence and token refresh. Retrieve a valid
  session through `auth.session` rather than maintaining a separate token store
  or refresh timer.
- Concurrent callers share one in-progress session initialization task.
  Clear that task when it finishes; do not cache a permanent "ready" result.
- Create an anonymous user only when the SDK reports that no session exists.
  Propagate connectivity and refresh failures rather than treating every error
  as a reason to create a new identity. A later attempt can retry.
- Keep networking out of views and SDK details inside the data/infrastructure
  layer. No generic API manager or additional pass-through service layers are
  needed.

## 3. Function payloads

Keep Swift request/response structs near their feature consumers, such as
`Features/AddCard/Data/CardTitleGeneration.swift`. Match the backend's existing
wire format. No shared TypeScript package or code generator is required.
The card-title request's `nativeWritingSystem` carries its language and script
description; [plan 06](06-language-config.md) supplies the client language data.

## 4. Uploads and content import

Build uploads in `Infrastructure/Media/`, using `{auth.uid()}/filename.ext`
inside the `ugc-*` buckets as required by storage policies. Use the user's
session for those operations; never the service-role key.

Implement the import adapter from [plan 03 §5](03-content-storage.md#5-swift-models-and-import).
It converts normalized server content into the local GRDB representation,
including embedded photo/audio metadata and the selected translation. Keep
server schema evolution separate from this adapter.

## 5. Verification

- Build from a fresh checkout with the committed xcconfig and confirm the
  public configuration resolves without copying a local file.
- Confirm an existing session is reused and a fresh installation can obtain an
  anonymous session.
- Confirm concurrent startup/session requests share initialization, and an
  offline or failed refresh does not trigger a new anonymous signup or block
  local GRDB screens.
- Invoke the functions with representative payloads and decode their responses.
- Upload a representative media file under the current user's prefix.
- Confirm imported content follows plan 03's mapping and validation rules.

Do not add tests without approval or open the iPhone simulator without asking.
Writing this plan does not add the SDK, change app code, or deploy anything.

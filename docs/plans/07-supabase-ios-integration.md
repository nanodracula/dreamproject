# Supabase iOS integration plan

Status: planned, not implemented. Extracted from plan 04 on September 13, 2026.

Integrate the Swift app with the existing self-hosted Supabase API. This work
is independent of the [repository migration](04-supabase-migration.md); that
migration can finish before the iOS client is implemented. Server schema
changes are outside this plan.

## 1. Client configuration

The iOS app needs `SUPABASE_URL` and the anon key. The anon key is public by
design — row-level security is what protects the data, and the existing
policies are correct: `select` on `status = 'published'` for `anon` and
`authenticated`, all writes to `service_role`, and storage insert/select/delete
gated on `(storage.foldername(name))[1] = auth.uid()`. It ships inside the IPA
regardless. The goal is to keep it out of scattered Swift source, not to hide it.

The Xcode equivalent of `EXPO_PUBLIC_*` is an xcconfig feeding Info.plist:

```sh
# apps/ios/Config/Supabase.xcconfig            (gitignored)
# apps/ios/Config/Supabase.example.xcconfig    (committed)
# xcconfig treats // as a comment, so break the scheme separator:
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
        else { fatalError("Missing \(key). Copy apps/ios/Config/Supabase.example.xcconfig to Supabase.xcconfig.") }
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

Wire the local xcconfig into the app's Debug and Release build configurations
and add `SUPABASE_URL` and `SUPABASE_ANON_KEY` substitutions to the app's
Info.plist configuration. Add an exact ignore rule for the local
`apps/ios/Config/Supabase.xcconfig`; `.env` ignore rules do not cover it. Commit
only `Supabase.example.xcconfig` and document copying it before building.

## 2. Client and anonymous session

Add `supabase-community/supabase-swift` through SPM beside GRDB. Put the client
and session handling in `Infrastructure/Supabase/`, wired by `AppDependencies`.
Mirror the old `ensureSession()` behavior: reuse a persisted session when
available and sign in anonymously when a session is needed and none exists.
Keep networking out of views.

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

- Build with the local xcconfig and confirm the public configuration resolves.
- Confirm an existing session is reused and a fresh installation can obtain an
  anonymous session.
- Invoke the functions with representative payloads and decode their responses.
- Upload a representative media file under the current user's prefix.
- Confirm imported content follows plan 03's mapping and validation rules.

Do not add tests without approval or open the iPhone simulator without asking.
Writing this plan does not add the SDK, change app code, or deploy anything.

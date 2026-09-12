# DreamProject

Native SwiftUI app: **DreamApp**, iPhone/iPad, iOS 26.0+, Swift 6.
Bundle ID: `com.example.DreamProject`. Project and shared scheme: `DreamApp`.
Sources: `apps/ios/DreamApp/`; tests: `apps/ios/DreamAppTests/` (synchronized folders).
Dependency: [GRDB](https://github.com/groue/GRDB.swift) 7 (Swift package, resolved by Xcode).
Backend: self-hosted Supabase in `server/supabase/`; runbook in `server/README.md`.
Architecture: `docs/architecture.md`. Storage plans: `docs/plans/`.

## Setup

Requires macOS, full Xcode, an iOS Simulator runtime, Git, Bash, and curl.
Verified September 12, 2026: Xcode 26.6 (17F113), iOS Simulator 26.5 (23F77),
mise 2026.9.5. iOS uses Xcode's bundled toolchain. mise manages the server
toolchain: Deno 2 and the Supabase CLI 2.65.2 (`[tools]` in `mise.toml`).
Setup checks passed: bootstrap installation/reuse, Simulator build/launch,
project paths, app inputs, and Git ignore rules.

From the repository root:

```sh
bash tools/bootstrap.sh
export PATH="$HOME/.local/bin:$PATH" # if mise is not already on PATH
```

Bootstrap checks prerequisites, installs mise if missing, trusts `mise.toml`,
and runs `mise install`. Safe to rerun; no shell activation required.

Deploying to the server additionally needs SSH access to the VPS and a
`server/.env.local` created from `server/.env.example`.

## Commands

```sh
mise run ios:build               # build for Simulator
mise run ios:run                 # build, install, launch on iPhone 17 Pro
xed apps/ios                    # open Xcode; Cmd+R builds and runs, Cmd+U tests
xcrun simctl list devices available
IOS_SIMULATOR_ID=<UDID> mise run ios:run
mise run ios:test -- -destination "platform=iOS Simulator,id=<UDID>"

mise run functions:check         # typecheck, lint, format-check the edge functions
mise run functions:deploy        # versioned edge-functions release to the VPS
mise run db:tunnel               # SSH tunnel to the remote Postgres
mise run db:deploy               # push pending migrations through the tunnel
```

`ios:test` runs the `DreamAppTests` unit tests (Swift Testing) on the given
Simulator destination. The tests use in-memory databases and isolated
`UserDefaults` suites; nothing touches the app's own data.

Tasks in `mise.toml` call `tools/run-ios.sh build|test|run`, which resolves
`apps/ios/` automatically, and `tools/supabase/*.sh` for the server. Platform
configuration stays with the app; repository helpers live in `tools/`.

`ios:run` uses incremental builds, exits after launch, and has no hot reload.
Cache: `~/Library/Developer/Xcode/DerivedData/DreamApp-Run`.

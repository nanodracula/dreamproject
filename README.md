# DreamProject

Native SwiftUI app: **DreamApp**, iPhone/iPad, iOS 26.0+, Swift 6.
Bundle ID: `com.example.DreamProject`. Project and shared scheme: `DreamApp`.
Sources: `apps/ios/DreamApp/`; tests: `apps/ios/DreamAppTests/` (synchronized folders).
Dependency: [GRDB](https://github.com/groue/GRDB.swift) 7 (Swift package, resolved by Xcode).
Settings storage: see `docs/02-settings-storage.md`.

## Setup

Requires macOS, full Xcode, an iOS Simulator runtime, Git, Bash, and curl.
Verified September 12, 2026: Xcode 26.6 (17F113), iOS Simulator 26.5 (23F77),
mise 2026.9.5. Uses Xcode's bundled toolchain; no mise-managed tools yet.
Setup checks passed: bootstrap installation/reuse, Simulator build/launch,
project paths, app inputs, and Git ignore rules.

From the repository root:

```sh
bash tools/bootstrap.sh
export PATH="$HOME/.local/bin:$PATH" # if mise is not already on PATH
```

Bootstrap checks prerequisites, installs mise if missing, trusts `mise.toml`,
and runs `mise install`. Safe to rerun; no shell activation required.

## Commands

```sh
mise run ios:build               # build for Simulator
mise run ios:run                 # build, install, launch on iPhone 17 Pro
xed apps/ios                    # open Xcode; Cmd+R builds and runs, Cmd+U tests
xcrun simctl list devices available
IOS_SIMULATOR_ID=<UDID> mise run ios:run
mise run ios:test -- -destination "platform=iOS Simulator,id=<UDID>"
```

`ios:test` runs the `DreamAppTests` unit tests (Swift Testing) on the given
Simulator destination. The tests use in-memory databases and isolated
`UserDefaults` suites; nothing touches the app's own data.

Tasks in `mise.toml` call `tools/run-ios.sh build|test|run`, which resolves
`apps/ios/` automatically. Platform configuration stays with the app;
repository helpers live in `tools/`.

`ios:run` uses incremental builds, exits after launch, and has no hot reload.
Cache: `~/Library/Developer/Xcode/DerivedData/DreamApp-Run`.

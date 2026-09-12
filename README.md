# DreamProject

Repository setup is in progress. Steps 1–3 provide the directory structure,
bootstrap tooling, and a minimal native SwiftUI iOS app. The test target will be
added in step 4. See [the setup plan](docs/01-init.md).

The app directories are `apps/ios/` and `apps/web/` (reserved for future work).
Android is outside the current repository scope.

The app targets iOS 26.0 and later on iPhone and iPad, using Swift 6 language mode.
Its development bundle identifier is `com.example.DreamProject`. Choose an owned
identifier and a signing team before physical-device distribution. The shared
`DreamProject` scheme is included in the project. Swift sources and assets live
in the synchronized `apps/ios/DreamProject/` folder assigned to the app target.
The app icon asset has empty slots ready for artwork.

## Prerequisites

- macOS with full Xcode, including its bundled Swift, `xcodebuild`, `xcrun`, and
  `xed`. Open Xcode once to accept its license and finish component installation.
- An available iOS Simulator runtime, installed through Xcode Settings > Components.
- Git, Bash, and curl from the macOS developer/system tools.
- mise, installed by bootstrap if missing. No additional mise-managed tools,
  Node.js, Java, Fastlane, or Docker are required at this stage.

Verified on the setup machine on September 12, 2026:

| Component | Selected version |
| --- | --- |
| Xcode | 26.6 (17F113) |
| Developer directory | `/Applications/Xcode.app/Contents/Developer` |
| iOS Simulator runtime | iOS 26.5 (23F77) |
| Example simulator | iPhone 17 Pro, iOS 26.5 |
| Git | 2.50.1 (Apple Git-155) |
| mise | 2026.9.5 (macos-arm64) |

These record the current machine; simulator IDs and installed versions can differ
on another machine. To select full Xcode when necessary:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## Bootstrap

From the repository root:

```sh
bash tools/bootstrap.sh
```

The script checks prerequisites, reuses mise from PATH or `~/.local/bin/mise`,
or installs it with the [official mise installer](https://mise.jdx.dev/installing-mise.html).
It verifies the executable, trusts this repository's `mise.toml`, and runs
`mise install` from the repository root. Review the configuration before running
bootstrap. It is safe to rerun and does not edit shell startup files.

If mise is not on your shell PATH after bootstrap, use its full path or add it
for the current terminal session:

```sh
export PATH="$HOME/.local/bin:$PATH"
mise --version
mise tasks ls
```

Shell activation is optional. Bootstrap can also be invoked by its absolute path
from another working directory.

## iOS commands

Task definitions live in root `mise.toml` and call `tools/run-ios.sh` with a
`build`, `test`, or `run` subcommand. The script resolves the repository root and
runs `xcodebuild` from `apps/ios/`, using `DreamProject.xcodeproj` and the shared
`DreamProject` scheme. Prerequisite checks happen during bootstrap; build and
test errors come directly from Xcode. You can also invoke the script directly,
for example `bash tools/run-ios.sh run` from the repository root.

Build and launch the app from the repository root:

```sh
mise run ios:run
```

This boots iPhone 17 Pro if needed, opens Simulator, builds the app, installs it,
and launches it. Rerun the same command after editing to rebuild incrementally
and relaunch. It exits after launch; it does not watch files or provide hot reload.
Xcode caches this task's builds in
`~/Library/Developer/Xcode/DerivedData/DreamProject-Run`, outside the repository.
The first run creates that cache; subsequent runs reuse it.

To use a different simulator (or disambiguate duplicate device names), select its
ID from the available devices:

```sh
xcrun simctl list devices available
IOS_SIMULATOR_ID=<SIMULATOR-UDID> mise run ios:run
```

Open the Simulator app:

```sh
open -a Simulator
```

This opens Simulator; it does not build or install DreamProject. To build and
run with Xcode's debugger, open the project in Xcode, select
an iPhone simulator, and press Cmd+R:

```sh
xed apps/ios
```

Build for iOS Simulator:

```sh
mise run ios:build
```

The equivalent command from the repository root, without mise, is:

```sh
xcodebuild -project apps/ios/DreamProject.xcodeproj -scheme DreamProject \
  -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

This builds the app without launching it. After step 4 adds the test target,
list available simulators,
then pass Xcode's standard `-destination` option:

```sh
xcrun simctl list devices available
mise run ios:test -- -destination "platform=iOS Simulator,id=<SIMULATOR-UDID>"
```

Replace `<SIMULATOR-UDID>` with a device ID from the list. Alternatively, use a
name and runtime installed on your machine:

```sh
mise run ios:test -- -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5"
```

If no devices are listed, create an iOS simulator in Xcode's Devices and
Simulators window. If Simulator services cannot be queried, open Xcode/Simulator
and retry from a normal terminal with access to those services.

#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root/apps/ios"

xcode() {
  xcodebuild \
    -project DreamProject.xcodeproj \
    -scheme DreamProject \
    -configuration Debug \
    "$@"
}

action="${1:-}"
if [ "$#" -gt 0 ]; then shift; fi

case "$action" in
  build)
    xcode -destination 'generic/platform=iOS Simulator' build "$@"
    ;;

  test)
    xcode -sdk iphonesimulator test "$@"
    ;;

  run)
    simulator="${IOS_SIMULATOR_ID:-iPhone 17 Pro}"
    destination="platform=iOS Simulator,name=iPhone 17 Pro"
    if [ -n "${IOS_SIMULATOR_ID:-}" ]; then
      destination="platform=iOS Simulator,id=$IOS_SIMULATOR_ID"
    fi
    derived_data="$HOME/Library/Developer/Xcode/DerivedData/DreamProject-Run"

    xcrun simctl bootstatus "$simulator" -b
    open -a Simulator
    xcode -destination "$destination" \
      -derivedDataPath "$derived_data" build

    app="$derived_data/Build/Products/Debug-iphonesimulator/DreamProject.app"
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")
    xcrun simctl install "$simulator" "$app"
    xcrun simctl launch --terminate-running-process "$simulator" "$bundle_id"
    ;;

  *)
    echo "Usage: bash tools/run-ios.sh build|test|run" >&2
    exit 2
    ;;
esac

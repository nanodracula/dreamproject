# iOS project configuration

App-level configuration that lives in the Xcode project rather than in Swift
source: appearance, orientation, launch screen, and similar Info.plist keys.
Design values belong in `docs/design.md`; layering rules belong in
`docs/architecture.md`. This file is for the settings that have to change for
the app to behave like the Expo app it replaces.

`DreamApp` has no `Info.plist` file. `GENERATE_INFOPLIST_FILE = YES`, so every
key comes from `INFOPLIST_KEY_*` build settings in
`apps/ios/DreamApp.xcodeproj/project.pbxproj`. Each setting below is applied to
both the Debug and Release configurations of the app target.

## Applied

Changed on September 12, 2026. Written directly into `project.pbxproj`; not yet
built or run, because this repository has no macOS or Xcode available.

### Dark appearance

```
INFOPLIST_KEY_UIUserInterfaceStyle = Dark;
```

The app is dark-only by design, not dark-by-default. In Expo this was
`userInterfaceStyle: "dark"` in `app.json`, which compiles to the
`UIUserInterfaceStyle` Info.plist key. Without it the app follows the device
setting, so a phone in light mode gets light alerts, a light keyboard, light
share sheets, and light SwiftUI default colors.

This covers surfaces a SwiftUI modifier cannot reach: the generated launch
screen, alerts and action sheets, keyboard appearance, share sheets, and any
UIKit-presented system UI.

`.preferredColorScheme(.dark)` on the root view is not a substitute. It applies
to the SwiftUI view tree only, leaves system-presented surfaces following the
device setting, and can flash light during launch before the first frame. With
this build setting in place, a root-view modifier is unnecessary — do not add one.

The status bar needs no separate setting: it follows the interface style, which
matches the Expo app's explicit `StatusBar style="light"`.

### Portrait only

```
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = UIInterfaceOrientationPortrait;
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;
```

The Expo app is `"orientation": "portrait"`. The Xcode template had allowed
portrait plus both landscapes on iPhone, and all four orientations on iPad.

Every layout recorded in `docs/design.md` assumes portrait: the 380pt feed hero,
the floating action rail, the tab bar inset 32 from each edge, and the
full-height paged feed.

Both idioms are now portrait. Revisit the iPad line if the iPad build is ever
meant to rotate; the iPhone line should stay as it is.

### Launch screen background

```
INFOPLIST_KEY_UILaunchScreen_BackgroundColor = LaunchBackground;
```

`UILaunchScreen_Generation = YES` with no background key produces a plain
system-background launch screen, so launching in light mode flashes white before
the app's first dark frame.

`LaunchBackground` is a color set added at
`apps/ios/DreamApp/Resources/Assets.xcassets/LaunchBackground.colorset/`,
sRGB `#208AEF` at full alpha — the Expo splash background. The asset catalog is
inside a synchronized folder group, so the new color set needs no `project.pbxproj`
file reference.

The setting takes the *name of a color set*, not a hex value; a literal color
there will not resolve.

## Open items

Configuration work the design extraction surfaced but that is not done.

### Splash logo

The Expo splash showed `assets/images/splash-icon.png` at 76 × 71 points,
centered on the blue, and the app then cross-faded it out over 600ms
(hold 20%, fade 50%, scaling 1 → 0.96, `Easing.out(Easing.quad)`); the full
animation is recorded under Navigation and shared chrome in `docs/design.md`.

The launch screen is currently the blue background only. A generated launch
screen can also show a centered image through
`INFOPLIST_KEY_UILaunchScreen_ImageName`, which needs an image set in the asset
catalog. The animated hand-off is app code, not configuration, and would be a
SwiftUI view over the root.

### Bundle identifier

`PRODUCT_BUNDLE_IDENTIFIER = com.example.DreamProject` is the template
placeholder. The Expo app used `com.anonymous.dreamproject`, itself a
placeholder. A real identifier is needed before any device build, TestFlight
upload, or push/Sign in with Apple capability.

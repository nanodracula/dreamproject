# iOS project configuration

App-level configuration that lives in the Xcode project rather than in Swift
source: appearance, orientation, launch screen, and similar Info.plist keys.
Design values belong in `docs/design.md`; layering rules belong in
`docs/architecture.md`. This file is for the settings that have to change for
the app to behave like the Expo app it replaces.

`DreamApp` uses `apps/ios/DreamApp/Resources/Info.plist` for its launch-screen dictionary.
`GENERATE_INFOPLIST_FILE = YES` lets Xcode merge that file with standard metadata
and supported `INFOPLIST_KEY_*` build settings from
`apps/ios/DreamApp.xcodeproj/project.pbxproj`. Settings below apply to both Debug
and Release. The source plist is excluded from the synchronized folder's target
membership so it is processed as configuration rather than copied as a resource.

## Applied

Configuration updated on September 13, 2026.

Unsigned Debug and Release builds for generic iOS succeeded with Xcode 26.6.
Both built app plists were inspected: `UILaunchScreen.UIColorName` is
`LaunchBackground`, `UIUserInterfaceStyle` is `Dark`, `UIDeviceFamily` contains
only `1`, and the iPhone orientation list contains only portrait. Launch appearance
has not yet been checked on a device or simulator.

### Dark appearance

```
INFOPLIST_KEY_UIUserInterfaceStyle = Dark;
```

The app is dark-only by design, not dark-by-default. In Expo this was
`userInterfaceStyle: "dark"` in `app.json`, which compiles to the
`UIUserInterfaceStyle` Info.plist key. Without it the app follows the device
setting, so a phone in light mode gets light alerts, a light keyboard, light
share sheets, and light SwiftUI default colors.

The plist declares the app-wide appearance before SwiftUI starts.
`.preferredColorScheme(.dark)` is also valid: it sets the appearance of the
enclosing presentation, such as a window or sheet, rather than just child views.
It does not configure the system launch screen. For this permanently dark app,
a root-view modifier would duplicate the plist policy and is unnecessary.
Use a SwiftUI preference if a future theme switch or individual presentation
needs a different appearance.

The default status-bar style adapts to the interface style. No separate override
is currently needed; revisit this if a screen overrides its appearance.

### iPhone only, portrait only

```
TARGETED_DEVICE_FAMILY = 1;
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;
```

The Expo app is `"orientation": "portrait"`. The Xcode template had allowed
portrait plus both landscapes on iPhone, and all four orientations on iPad.

Every layout recorded in `docs/design.md` assumes portrait: the 380pt feed hero,
the floating action rail, the tab bar inset 32 from each edge, and the
full-height paged feed.

As of September 13, 2026, native iPad support is out of scope. The app and test
targets use the iPhone device family in both Debug and Release, and the unused
iPad orientation setting is removed. Revisit device support and adaptive layouts
if native iPad support is added later.

### Launch screen background

```xml
<key>UILaunchScreen</key>
<dict>
    <key>UIColorName</key>
    <string>LaunchBackground</string>
</dict>
```

This dictionary in `DreamApp/Resources/Info.plist` gives the system launch screen an
explicit blue background. Both app configurations set
`INFOPLIST_FILE = DreamApp/Resources/Info.plist`.
`INFOPLIST_KEY_UILaunchScreen_Generation` is removed because the source plist now
supplies the dictionary. The previous `INFOPLIST_KEY_UILaunchScreen_BackgroundColor`
setting was unsupported: arbitrary `INFOPLIST_KEY_*` names do not generate nested
plist entries.

`LaunchBackground` is a color set added at
`apps/ios/DreamApp/Resources/Assets.xcassets/LaunchBackground.colorset/`,
sRGB `#208AEF` at full alpha — the Expo splash background. The asset catalog is
inside a synchronized folder group, so the new color set needs no `project.pbxproj`
file reference.

`UIColorName` takes the *name of a color set*, not a hex value; a literal color
there will not resolve.

## Open items

Configuration work the design extraction surfaced but that is not done.

### Splash logo

The Expo splash showed `assets/images/splash-icon.png` at 76 × 71 points,
centered on the blue, and the app then cross-faded it out over 600ms
(hold 20%, fade 50%, scaling 1 → 0.96, `Easing.out(Easing.quad)`); the full
animation is recorded under Navigation and shared chrome in `docs/design.md`.

The launch screen is currently the blue background only. To add a static logo,
add an image set to the asset catalog and reference it with `UIImageName` inside
the `UILaunchScreen` dictionary. If precise size and positioning require layout
constraints, use a launch storyboard. The animated hand-off is deferred; it would
be a SwiftUI view over the root, not launch-screen configuration.

### Bundle identifier

`PRODUCT_BUNDLE_IDENTIFIER = com.example.DreamProject` is the template
placeholder. The Expo app used `com.anonymous.dreamproject`, itself a
placeholder. Choose a stable, unique identifier before distribution or configuring
push notifications or Sign in with Apple. Development device builds also need
signing and provisioning for the chosen identifier.

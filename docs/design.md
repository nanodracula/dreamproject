# Design reference

Extracted from the Expo app in `nanodracula/dreamproject-old` at commit `effe870`,
for recreating the same design in SwiftUI.

This is a record of what the old app draws, value for value. It is not a design
system and makes no attempt to unify the palettes, which genuinely differ per
screen. Every number and color here appears verbatim in the source; the `Source:`
line on each section points at the file it came from.

## Contents

- [Global tokens](#global-tokens)
- [Navigation and shared chrome](#navigation-and-shared-chrome)
- [Dictionary](#dictionary)
- [Feed](#feed)
- [Add card](#add-card)
- [Settings](#settings)
- [Word lookup](#word-lookup)
- [Player](#player)
- [Dev tools](#dev-tools)

## Reading conventions

- All numbers are React Native density-independent pixels, which equal SwiftUI
  points 1:1. No conversion needed.
- `Spacing.three (16)` means the source writes the token and it resolves to 16.
- `lineHeight` is an **absolute** line box height in RN, not a gap. SwiftUI's
  `.lineSpacing` is the gap between lines, so it is not the same number.
- `fontWeight` is numeric in RN: 300, 400, 500, 600, 700.
- `borderCurve: 'continuous'` is the squircle; the default is `'circular'`.
- `StyleSheet.hairlineWidth` is 1 physical pixel (0.333 at @3x).
- Icon names are SF Symbols and are written exactly as the source passes them.
- The app is dark-only: `userInterfaceStyle: "dark"` is forced in `app.json`
  and `useTheme()` always returns `Colors.dark` regardless of the system setting.

## Recurring interaction values

These appear across many files, always as a `pressed` style:

| Value | Where |
| --- | --- |
| `opacity: 0.6` | Dictionary rows |
| `opacity: 0.65` | Title-options sheet controls |
| `opacity: 0.7` | Circle button, tabs, headers, add-card, feed retry |
| `opacity: 0.4` | Disabled rows, dimmed dev controls |

## Global tokens

Source: `src/theme/tokens.ts`, `src/hooks/use-theme.ts`, `src/theme/content-font.ts`,
`src/components/themed-text.tsx`, `src/components/themed-view.tsx`,
`src/providers/navigation-theme-provider.tsx`, `app.json`.

### Colors

The only namespace is `Colors.dark`. `useTheme()` returns it unconditionally.

| Token | Hex | Used for |
| --- | --- | --- |
| `text` | `#ffffff` | Default text color for `ThemedText` |
| `background` | `#151c26` | Default `ThemedView` background, solid tab-bar fallback |
| `backgroundElement` | `#1e2949` | Navigation `card` color |
| `backgroundSelected` | `#2E3135` | Navigation `border` color |
| `textSecondary` | `#B0B4BA` | Secondary text, inactive tab-bar glyphs |
| `accent` | `#62B0FF` | Navigation `primary` and `notification` |
| `accentSoft` | `#173B5C` | Feed retry button fill, active rail circle |

A commented-out alternative for `background` is present in the source: `#1C2127`.

`ThemedView` takes an optional `type` naming any of these tokens; with no `type`
it fills with `background`. `ThemedText` takes an optional `themeColor` the same
way, defaulting to `text`.

#### PseudoGlass

Used where a real glass view cannot be (see [Navigation and shared chrome](#navigation-and-shared-chrome)).

| Token | Value |
| --- | --- |
| `borderColor` | `rgba(255, 255, 255, 0.12)` |
| `highlightColor` | `rgba(255, 255, 255, 0.04)` |

### Fonts

No custom fonts are bundled and nothing calls `useFonts`. Everything is the
system font, selected on iOS through design descriptors:

| Token | iOS value | Descriptor |
| --- | --- | --- |
| `sans` | `system-ui` | `UIFontDescriptorSystemDesignDefault` |
| `serif` | `ui-serif` | `UIFontDescriptorSystemDesignSerif` |
| `rounded` | `ui-rounded` | `UIFontDescriptorSystemDesignRounded` |
| `mono` | `ui-monospace` | `UIFontDescriptorSystemDesignMonospaced` |

Only `mono` is actually referenced, by the `code` text type and the Terminal screen.

#### Content fonts

`getContentFontStyle(lang)` returns a `fontFamily` override applied on top of the
regular text style, for learning content only — words, sentences, and their
readings. Interface text never uses it. It returns `undefined` off iOS.

| Language code | `contentFontFamily` |
| --- | --- |
| `ja` | `Hiragino Sans` |
| `zh-Hant` | `PingFang TC` |
| `ko` | none declared |
| `pl` | none declared |
| `uk` | none declared |

Source comment: only Han-script languages declare a family, to stop iOS from
choosing Japanese or Chinese glyph forms by device language instead of by the
text.

Applied at: breakdown chip phonetic and main text, dictionary row primary text
(title fallback only, not transliteration), dictionary item sheet title,
lookup word and base form, title-option titles.

### Spacing

| Token | Value |
| --- | --- |
| `Spacing.half` | 2 |
| `Spacing.one` | 4 |
| `Spacing.two` | 8 |
| `Spacing.three` | 16 |
| `Spacing.four` | 24 |
| `Spacing.five` | 32 |
| `Spacing.six` | 64 |

Composite values appear inline where a step is missing, e.g. `Spacing.two + Spacing.one`
(12), `Spacing.two + Spacing.half` (10), `Spacing.one + Spacing.half` (6).

### Layout constants

| Constant | Value | Meaning |
| --- | --- | --- |
| `BottomTabInset` | 50 on iOS, 80 on Android | Space reserved under content for the floating tab bar |
| `MaxContentWidth` | 800 | Declared; no current consumer |

Screens combine it as `insets.bottom + BottomTabInset` for their bottom padding.

### Type scale

`ThemedText` variants, `src/components/themed-text.tsx`:

| Type | Size | Line height | Weight | Color |
| --- | --- | --- | --- | --- |
| `title` | 48 | 52 | 600 | theme `text` |
| `subtitle` | 32 | 44 | 600 | theme `text` |
| `default` | 16 | 24 | 500 | theme `text` |
| `small` | 14 | 20 | 500 | theme `text` |
| `smallBold` | 14 | 20 | 700 | theme `text` |
| `link` | 14 | 30 | inherited | theme `text` |
| `linkPrimary` | 14 | 30 | inherited | `#3c87f7` |
| `code` | 12 | — | 500 (700 on Android) | theme `text`, `Fonts.mono` |

Most screens do not use these variants; they declare size, line height, and
weight inline. Those values are recorded per screen in the other files.

### App chrome

From `app.json`:

| Key | Value |
| --- | --- |
| `userInterfaceStyle` | `dark` (root and iOS) |
| `backgroundColor` | `#151c26` (root and iOS) |
| Splash background | `#208AEF` |
| Splash image width | 76 |
| Android adaptive icon background | `#E6F4FE` |
| Orientation | `portrait` |

`StatusBar` style is `light`, set in `NavigationThemeProvider`.

#### Project configuration

The app is dark-only, portrait-only, and launches on the splash blue. Those are
Xcode build settings rather than design values, so they live in
`docs/ios-configuration.md` along with the rest of the project-level
configuration this reference implies.

#### Navigation theme

Expo Router's `DarkTheme` with these overrides:

| Navigation key | Token |
| --- | --- |
| `primary` | `Colors.dark.accent` `#62B0FF` |
| `background` | `Colors.dark.background` `#151c26` |
| `card` | `Colors.dark.backgroundElement` `#1e2949` |
| `text` | `Colors.dark.text` `#ffffff` |
| `border` | `Colors.dark.backgroundSelected` `#2E3135` |
| `notification` | `Colors.dark.accent` `#62B0FF` |

#### Entry route

`src/app/index.tsx` redirects to `/dictionary`, so Dictionary is the launch screen.

## Navigation and shared chrome

Source: `src/components/glass-navigation.tsx`, `glass-sliding-tabs.tsx`,
`screen-header.tsx`, `header-veil.tsx`, `button.tsx`, `bottom-sheet.tsx`,
`animated-icon.tsx`, `pronunciation-icon.tsx`, `src/app/(tabs)/_layout.tsx`.

### Tab bar (GlassNavigation)

A floating capsule, not a standard tab bar. Rendered as `GlassView` with
`glassEffectStyle="regular"` when glass is available, otherwise a plain view
filled with `Colors.dark.background`.

#### Metrics

| Constant | Value |
| --- | --- |
| `BarHeight` | 58 |
| `BarPadding` | 6 |
| `BarBorderWidth` | 1 |
| `BorderColor` | `rgba(255, 255, 255, 0.12)` |
| `BarBottomDip` | 12 |
| `HighlightHeight` | 44 (`BarHeight - BarPadding*2 - BarBorderWidth*2`) |
| `IconWellWidth` | 48 |
| `IconWellHeight` | 40 |
| `IconSize` | 23 |

Bar insets: `left` and `right` are `Spacing.five` (32). Corner radius is
`BarHeight / 2` (29) with `borderCurve: 'continuous'`. `overflow: 'hidden'`.

Vertical position: `bottom = max(insets.bottom - BarBottomDip, Spacing.two)`,
i.e. the bar dips 12 into the home-indicator area but never closer than 8.

#### Layers

| Layer | Value |
| --- | --- |
| Selection pill | `rgba(255, 255, 255, 0.14)`, height 44, radius 22, continuous |
| Press glow (whole bar) | `rgba(255, 255, 255, 0.06)`, radius 29, continuous |
| Active glyph tint | `#E9ECEF` |
| Inactive glyph tint | `Colors.dark.textSecondary` `#B0B4BA` |

The pill is a single shared view moved with `translateX` and stretched with
`scaleX`; it is never re-laid out per frame. Glass-in-glass is unsupported
(renders flat), so the pill is a plain translucent fill over the bar's glass.

#### Tabs

Order and symbols, from `src/app/(tabs)/_layout.tsx`:

| Route | Default symbol | Selected symbol | Label |
| --- | --- | --- | --- |
| `dictionary` | `books.vertical` | `books.vertical.fill` | Dictionary |
| `feed` | `rectangle.stack` | `rectangle.stack.fill` | Feed |
| `add` | `plus.circle` | `plus.circle.fill` | Add |
| `player` | `play.circle` | `play.circle.fill` | Player |
| `settings` | `gearshape` | `gearshape.fill` | translated `settings:title` |

Unknown routes fall back to `questionmark.circle` / `questionmark.circle.fill`.

Screen transition is `animation: 'fade'`, `headerShown: false`,
`detachInactiveScreens: false`.

#### Motion

| Spring | damping | stiffness | mass | Used for |
| --- | --- | --- | --- | --- |
| `LeadingSpring` | 30 | 400 | 0.7 | Pill edge racing ahead |
| `TrailingSpring` | 28 | 240 | 0.9 | Pill edge catching up |
| `IconSpring` | 14 | 300 | 0.6 | Glyph pop and press lift |
| `BarBounceSettleSpring` | 15 | 300 | 0.7 | Bar settle after a move |
| `BarReturnSpring` | 18 | 250 | 0.8 | Return from fullscreen |

Timings: bar bounce `withTiming(1.02, 140ms, Easing.out(Easing.sin))` before the
settle spring. Hide `withDelay(400ms, withTiming(1, 220ms, Easing.in(Easing.quad)))`.
Press glow in 80ms, out 250ms. Press scale 1.02 (bar), 1.06 (icon).
Landing pop `withDelay(120ms, sequence(spring(1.04), spring(1)))`.

The selected glyph crossfades by pill distance:
`opacity = max(0, 1 - |pillCenter - slotIndex|)`, and the default glyph is its
inverse.

### Sliding tabs (GlassSlidingTabs)

Used by Add card. Pseudo-glass, not real glass: `BlurView` at intensity 50,
tint `systemChromeMaterialDark`, plus a `PseudoGlass` border and highlight.

| Constant | Value |
| --- | --- |
| `BarRadius` | 20 |
| `BarPadding` | 4 |
| `SegmentRadius` | 16 (`BarRadius - BarPadding`) |
| `GlassSlidingTabsHeight` | 40 (`BarRadius * 2`) |
| `StretchPx` | 16 |
| `SwipeDirectionGain` | 10 |
| `TravelSpring` | damping 30, stiffness 260, mass 0.8 |

| Element | Value |
| --- | --- |
| Segment height | 32 (`SegmentRadius * 2`) |
| Segment padding | 12 horizontal, gap 7 |
| Segment icon size | 20 |
| Label | 15 / 20 / weight 500 |
| Pill fill | `rgba(255, 255, 255, 0.14)`, radius 16 |
| Pressed (inactive only) | `opacity: 0.7` |

Active and inactive tints are passed in by the caller, not fixed here.
The scroll viewport is inset by `margin: BarPadding` and clipped at
`SegmentRadius` so scrolled content curves with the pill.

Stretch: the leading edge reaches `StretchPx * 4 * t * (1 - t)` past the outline
mid-travel, peaking at 16 at the midpoint and vanishing at both ends.

### Screen header

| Property | Value |
| --- | --- |
| `ScreenHeaderHeight` | 44 |
| Title | 17 / 22 / weight 600, centered |
| Leading slot | absolute left, back `CircleButton` with `chevron.left` |
| Trailing slot | absolute right |

Comment in source: "Native UINavigationBar title metrics."

### Header veil

Dims content scrolling under floating top chrome.

| Constant | Value |
| --- | --- |
| `VeilOpacity` | 0.6 |
| `FadeHeight` | 32 |

A solid `rgba(0, 0, 0, 0.6)` block of the given height, then a 32-tall gradient
from `rgba(0, 0, 0, 0.6)` to `rgba(0, 0, 0, 0)` immediately below it.

### Circle button

| Property | Value |
| --- | --- |
| `CircleButtonSize` | 44 (default `size`) |
| Default icon size | 20 |
| Default blur | 50, tint `systemChromeMaterialDark` |
| Default tint color | `#ffffff` |
| Border | 1, `PseudoGlass.borderColor` |
| Fill | `PseudoGlass.highlightColor` |
| Radius | `size / 2` |
| Pressed | `opacity: 0.7` |
| Hit slop | `Spacing.two` (8) |

Source comment: header buttons use pseudo-glass because native `GlassView` can
disappear during the router's `fade` transition (expo/expo#48994).

### Bottom sheet

Two-detent sheet portaled above the navigator.

#### Appearance

| Property | Value |
| --- | --- |
| Background (iOS/web) | `rgba(36, 41, 53, 0.7)` over a `BlurView` intensity 50, tint `systemThickMaterialDark` |
| Background (Android) | `#242935` solid, no blur |
| Top corners | `Spacing.four` (24), `overflow: 'hidden'` |
| Rim | 1, `rgba(255, 255, 255, 0.12)` |
| Top padding | 10 |
| Grab handle | 44 × 5, radius 2.5, `rgba(255, 255, 255, 0.22)`, centered, 8 below |
| Close button | 30 × 30, radius 15, `rgba(255, 255, 255, 0.12)`, at top 13, right 16 |
| Close button pressed | `rgba(255, 255, 255, 0.22)` |
| Close glyph | `xmark`, 13, weight semibold, `rgba(255, 255, 255, 0.85)` |
| Header zone | padding 16 horizontal, min height 43 (`5 + 8 + 30`) |
| Content | padding 16 horizontal, 8 top |
| Footer | padding 16 horizontal, 8 top, plus `insets.bottom + 8` |

Source comment on the background: "Feed background (#191C23) lifted one elevation
step, same hue."

#### Detents and motion

| Constant | Value |
| --- | --- |
| `DEFAULT_BASE_FRACTION` | 0.5 |
| `DEFAULT_EXPANDED_FRACTION` | 0.75 |
| `DISMISS_DISTANCE_RATIO` | 0.25 |
| `FLING_VELOCITY` | 900 |
| `OPEN_TIMING` | 150ms, `Easing.out(Easing.cubic)` |
| `SNAP_SPRING` | stiffness 300, damping 36, `overshootClamping: true` |
| `CLOSE_DURATION_MS` | 200 |
| `RUBBER_COEFFICIENT` | 0.55 |
| `RUBBER_MAX_STRETCH` | 64 |

The base detent can be set by `anchorY` (window Y of the sheet's top edge)
instead of a fraction; the feed uses that to anchor the lookup drawer under the
tapped word.

Rubber band past the expanded detent:
`give = (1 - 1 / (overshoot * 0.55 / 64 + 1)) * 64`.

### Pronunciation icon

| State | Symbol | Tint |
| --- | --- | --- |
| Idle | caller's `idleIcon` | caller's `idleColor` |
| Playing, normal speed | `stop.circle` | `#fa5d7d` |
| Playing, slow speed | `stop.circle` | `#f5c542` |

While playing it runs a repeating `pulse` symbol effect, and it can render at a
larger `activeSize` than its idle `size`.

### Splash overlay

| Property | Value |
| --- | --- |
| Background | `#208AEF` |
| Image | `splash-icon.png`, 76 × 71, `contentFit: 'contain'` |
| `zIndex` | 1000 |
| `DURATION` | 600ms |
| `FADE_DELAY` | 120ms (20% of duration) |
| `FADE_DURATION` | 300ms (50% of duration) |
| Easing | `Easing.out(Easing.quad)` |
| Scale | 1 → 0.96 over the full duration |

Opacity holds at 1 for the first 20% so the native splash hide never shows through.

## Dictionary

Source: `src/features/dictionary/` — `lib/dictionary-theme.ts`,
`screens/dictionary-screen.tsx`, `components/dictionary-header.tsx`,
`dictionary-tabs.tsx`, `dictionary-row.tsx`, `dictionary-item-sheet.tsx`.

The launch screen. A `FlashList` of entries grouped by month under fixed chrome.

### Palette

`DictionaryColors` — the feature's components declare no colors of their own.

| Token | Value | Used for |
| --- | --- | --- |
| `background` | `#111318` | Screen, list, entry rows, sticky headers |
| `groupHeaderFill` | `rgba(255, 255, 255, 0.00)` | Month header band (fully transparent) |
| `groupToggleFill` | `rgba(255, 255, 255, 0.08)` | Month expand/collapse arrow highlight |
| `surface` | `#1e232c` | Thumbnails without a photo, retry button, banner |
| `text` | `#ffffff` | Primary text |
| `secondary` | `#9aa0aa` | Translations, counts, chevrons |
| `accent` | `#fa5d7d` | Spinners, sort control, playing speaker |
| `failure` | `#ff6259` | Failed-card count |
| `headerButtonFill` | `rgba(17, 19, 24, 0.55)` | Search/settings circles over artwork |
| `headerButtonBorder` | `rgba(255, 255, 255, 0.22)` | Their outline |
| `artworkGradient` | `['rgba(17, 19, 24, 0)', 'rgba(17, 19, 24, 0.55)', '#111318']` | Scrim over the artwork |
| `inactiveTabFill` | `rgba(19, 31, 34, 0.82)` | Inactive tab pills |
| `inactiveTabBorder` | `#263438` | Their outline |
| `activeTabFill` | `#b83f5a` | Active tab pill |
| `activeTabBorder` | `#cc5771` | Its outline |

`DictionaryMenuColors`, used only by the item sheet:

| Token | Value |
| --- | --- |
| `background` | `#202126` |
| `group` | `#2c2d33` |
| `pressed` | `#3a3b42` |
| `ripple` | `rgba(255, 255, 255, 0.12)` |
| `separator` | `rgba(255, 255, 255, 0.09)` |

### Header

Top padding is `insets.top + Spacing.two` (8).

#### Artwork band

| Property | Value |
| --- | --- |
| `ARTWORK_BAND` | 150 |
| Total height | `insets.top + 150` |
| Position | absolute, top/left/right 0, `pointerEvents: 'none'` |
| Image fit | `cover` |
| Scrim | `artworkGradient`, three stops, full bleed |

Artwork is per learning language and only two exist; other languages show the
plain background:

| Code | Asset |
| --- | --- |
| `ja` | `assets/images/languages/dict-header-ja.jpeg` |
| `ko` | `assets/images/languages/dict-header-ko.jpeg` |

#### Title row

| Element | Value |
| --- | --- |
| Layout | row, space-between, gap 8, padding 16 horizontal |
| Title | 17 / 22 / weight 600, centered, `flex: 1`, `text` |
| `HEADER_BUTTON_SIZE` | 40, radius 20 |
| Button border | `StyleSheet.hairlineWidth`, `headerButtonBorder` |
| Button fill | `headerButtonFill` |
| Button glyph | 18, weight medium, `text` |
| Leading glyph | `magnifyingglass` |
| Trailing glyph | `slider.horizontal.3` |
| Pressed | `opacity: 0.7` |
| Hit slop | `Spacing.one` (4) |

Both header buttons are visual only; search and settings are not wired.

Title text is `dictionary.title` interpolated with the learning language's name.

#### Tab pills

Tabs sit `Spacing.four` (24) below the title row, in a horizontal scroll view.

| Property | Value |
| --- | --- |
| `PILL_HEIGHT` | 36 |
| Scroll container height | 44 (`PILL_HEIGHT + Spacing.two`) |
| Row | gap 8, padding 16 horizontal, 4 vertical |
| Pill radius | 10, continuous |
| Pill padding | 10 horizontal (`Spacing.two + Spacing.half`), gap 6 |
| Pill border | 1 |
| Icon | 18, weight light, `text` |
| Label | 14 / 18 / weight 400, `text`, single line |
| Inactive | fill `inactiveTabFill`, border `inactiveTabBorder` |
| Active | fill `activeTabFill`, border `activeTabBorder` |
| Pressed (inactive only) | `opacity: 0.7` |
| Hit slop | 4 top and bottom |

Note: the label color is the same `#ffffff` in both states; only the fill and
border change.

#### Count row

| Element | Value |
| --- | --- |
| Layout | row, space-between, gap 8, 16 below the tabs, 16 horizontal, 8 bottom |
| Count | 14 / 18, `secondary`, `flex: 1` |
| Sort control | row, gap 4 |
| Sort glyph | `arrow.up.arrow.down`, 13, weight semibold, `accent` |
| Sort label | 14 / 18 / weight 600, `accent` |

Sorting is not implemented; the control only displays the fixed order.

In selection mode the row becomes Cancel / centered selected-count / actions,
where both actions use the sort-label style and the disabled action adds
`opacity: 0.4`.

#### Regeneration banner

| Property | Value |
| --- | --- |
| Container | margin 16 horizontal, 8 bottom; padding 16 horizontal, 8 vertical; gap 4 |
| Radius | 16, continuous |
| Fill | `surface` |
| Row | row, gap 8, with an `ActivityIndicator` in `accent` while running |
| Text | 14 / 18, `text`, `flex: 1` |
| Failed line | 13 / 18 / weight 600, `failure` |
| Failure list | `maxHeight: 72` |
| Failure item | 12 / 16, `secondary` |
| Dismiss glyph | `xmark`, 13, weight semibold, `secondary` |

### List rows

#### Month header

| Property | Value |
| --- | --- |
| `GROUP_HEADER_HEIGHT` | 34 |
| Layout | row, space-between, gap 8; margin-top 4; padding left 16, right 8 |
| Fill | `groupHeaderFill` (transparent) |
| Sticky variant | fills with `background` |
| Chevron | `chevron.right` collapsed / `chevron.down` expanded, 14, weight semibold, `text` |
| Label | 14 / 20 / weight 500, `secondary`, single line |
| Label content | `"<Month Year> (<count>)"`, month via `Intl.DateTimeFormat`, UTC, capitalized |

Checkbox (selection mode only):

| Property | Value |
| --- | --- |
| Button | 28 wide × 34 tall, aligned right |
| Box | 18 × 18, radius 4, border 1 `secondary` |
| Checked | border and fill `accent` |
| Hit slop | 4 top and bottom |

#### Entry row

| Property | Value |
| --- | --- |
| `ENTRY_ROW_MIN_HEIGHT` | 72 |
| Padding | 10 vertical (`Spacing.two + Spacing.half`), left 16, right 8 |
| Fill | `background` |
| `THUMBNAIL_SIZE` | 56, radius 6, continuous, placeholder fill `surface` |
| Thumbnail margin-right | 12 (`Spacing.two + Spacing.one`) |
| Text block | `flex: 1`, margin-right 4, gap 2 |
| Primary | 16 / 22 / weight 600, `text` |
| Translation | 14 / 20, `secondary`, single line, tail ellipsis |
| `ROW_BUTTON_SIZE` | 36 |
| Speaker | idle `speaker.wave.2.fill` 18, active 24, idle tint `secondary` |
| More button | 28 wide, `ellipsis` 18, `secondary`, rotated 90° |
| Pressed | `opacity: 0.6` |
| Hit slop | 4 top and bottom |

The primary line shows `writingTransliterated`, falling back to `title` when it
is empty; the fallback gets the language content font, the transliteration does not.

Rows without a photo get a bundled placeholder chosen deterministically from the
entry id, so an entry keeps the same picture across visits:

- Default: `img-placeholder.jpeg`, `img-placeholder-2.jpeg`, `japanese-cafe.jpeg`
- Korean: `korean-hanok.jpeg`, `korean-mountains.jpeg`, `korean-seoul-evening.jpeg`,
  `korean-jeju-coast.jpeg`, `korean-palace-garden.jpeg`

### List states

Bottom content inset: `insets.bottom + BottomTabInset + Spacing.three`.

| State | Content |
| --- | --- |
| Loading | Centered `ActivityIndicator` in `accent` |
| Loading more | Footer `ActivityIndicator` in `accent`, 24 vertical padding |
| Error | `exclamationmark.triangle` 36 in `secondary`, title, retry button |
| Empty, all | `book.closed` 36 in `secondary` |
| Empty, favorites | `heart` 36 |
| Empty, drafts | `square.and.pencil` 36 |

| Element | Value |
| --- | --- |
| Empty container | absolute fill, centered, gap 8, padding 32 horizontal, `BottomTabInset` bottom |
| Empty title | 17 / 22 / weight 600, centered, `text` |
| Empty hint | 14 / 20, centered, `secondary` |
| Retry button | margin-top 8, padding 24 horizontal / 8 vertical, radius 16 continuous, fill `surface` |
| Retry label | 15 / 20 / weight 600, `accent` |
| Retry pressed | `opacity: 0.7` |

Haptics: `Haptics.ImpactFeedbackStyle.Light` on beginning a selection, toggling
an entry, and toggling a month (one pulse per month regardless of entry count).

### Item sheet

A native `@expo/ui` `BottomSheet` with `containerColor: DictionaryMenuColors.background`
and `contentPadding: 0`. Initial measured content height 380.

| Element | Value |
| --- | --- |
| Header | padding 16 horizontal, 24 top, gap 8 |
| Heading | 17 / 23 / weight 600, `DictionaryColors.text`, `flex: 1` |
| Close button | 30 × 30, radius 15, fill `DictionaryMenuColors.group` |
| Close glyph | `xmark`, 13, weight semibold, `DictionaryColors.secondary` |
| Close pressed | fill `DictionaryMenuColors.pressed` |
| Header divider | hairline, `DictionaryMenuColors.separator`, margin -16 horizontal (full bleed) |
| Item title | 14 / 20, `DictionaryColors.secondary`, up to 2 lines |
| Menu | gap 16, padding 16 horizontal, 16 top, 24 bottom |
| Group | radius 12, continuous, fill `DictionaryMenuColors.group`, clipped |
| Menu row | min height 52, gap 16, padding 16 horizontal, 12 vertical |
| Menu label | 17 / 23, `DictionaryColors.text`, `flex: 1` |
| Menu icon | 21, same color unless overridden |
| Row separator | hairline, `separator`, inset 16 left |
| Disabled row | `opacity: 0.4` |
| Pressed (non-Android) | fill `DictionaryMenuColors.pressed` |
| Android ripple | `DictionaryMenuColors.ripple` |

Rows, in order, grouped as shown:

1. Select (`checkmark.circle`) — single-item mode only; Favorite / Unfavorite
   (`heart` / `heart.fill`, tinted `DictionaryColors.accent` when favorited)
2. Regenerate audio (`waveform`), Regenerate photo (`photo`) — both disabled
   while a batch runs
3. Archive (`archivebox`) — placeholder, no handler

Rows without a handler are visual placeholders for unbuilt actions.

## Feed

Source: `src/features/feed/` — `lib/feed-theme.ts`, `screens/feed-screen.tsx`,
`components/feed-card.tsx`, `feed-card-hero.tsx`, `breakdown-chips.tsx`.

Full-screen vertically paged cards. Each card is a photo hero with the sentence
laid over its bottom edge, a body below, and a right-hand action rail.

### Palette

`FeedColors`. Source comment: intentionally darker than the app background, kept
out of the theme tokens because it will become dynamic (derived from the card
image) later.

| Token | Value | Used for |
| --- | --- | --- |
| `background` | `#111318` | Behind the card and the screen |
| `surface` | `#1e2949` | Elevated surface, the tip card |
| `accent` | `#62B0FF` | Section label, tip icon, active rail |
| `accentSoft` | `#173B5C` | Tip icon circle, active rail circle, retry fill |
| `textSecondary` | `rgba(255, 255, 255, 0.85)` | Translation line |
| `textMuted` | `rgba(255, 255, 255, 0.76)` | Furigana and romaji |
| `railIcon` | `rgba(255, 255, 255, 0.08)` | Rail icon circle at rest |
| `heroControl` | `rgba(10, 14, 20, 0.55)` | Backdrop behind hero header buttons |
| `chipSelectedBorder` | `#E8C158` | Outline on the chip whose lookup is open |

Two alternatives for `background` are commented out in the source: `#12141a` and
`rgb(4 9 13)` ("original in our first version of React Native").

### Hero

| Property | Value |
| --- | --- |
| `IMAGE_HEIGHT` | 380 |
| Image fit | `cover`, absolute fill |
| Content alignment | bottom (`justifyContent: 'flex-end'`) |
| Subtitle padding | top `HeroFade.lead` (120), 16 horizontal, 24 bottom |

#### Hero fade

A generated multi-stop `LinearGradient` over the bottom of the photo, behind the
chips. Parameters, all in `feed-theme.ts`:

| Parameter | Value | Meaning |
| --- | --- | --- |
| `HERO_FADE_RGB` | `0, 0, 0` (from `#000000`) | Tint of the fade |
| `HERO_FADE_PEAK` | 0.84 | Opacity at the bottom edge; scales every stop |
| `HERO_FADE_STRENGTH` | 0.65 | Darkness at the midpoint; pulls the curve's midpoint |
| `HERO_FADE_STOPS` | 4 | Number of gradient stops (10 is commented out) |
| `HERO_FADE_LEAD` | 120 | Room above the chips for the fade to ease in |

Stop positions are evenly spaced `i / (stops - 1)`. Alpha at each stop is
`heroFadeAlpha(t, 0.65) * 0.84` where:

```
x = t / ((1 / bias - 2) * (1 - t) + 1)
alpha = x * x * x * (x * (x * 6 - 15) + 10)
```

That is a bias-warped smootherstep: transparent at the top so it dissolves into
the photo, solid at the bottom so it merges into the card.

Resulting four stops:

| Location | Color |
| --- | --- |
| 0 | `rgba(0, 0, 0, 0)` |
| 0.3333 | `rgba(0, 0, 0, 0.3909)` |
| 0.6667 | `rgba(0, 0, 0, 0.7832)` |
| 1 | `rgba(0, 0, 0, 0.84)` |

Source note: set the tint equal to `FeedColors.background` and the peak to 1 to
merge the bottom edge into the card; lower the peak to leave photo showing through.

### Breakdown chips

Word chips over the hero fade, with furigana above and romaji below. Both
readings carry a shadow so they hold up over the photo.

#### Chip colors by part of speech

Each chip has a tinted fill with a softer outline of the same hue, so the same
particle is always the same color across cards.

| Group | Parts of speech | Fill | Border |
| --- | --- | --- | --- |
| Noun | `NOUN`, `PROPN`, `PRON`, `NUM` | `rgba(41, 70, 127, 0.92)` | `rgba(122, 156, 224, 0.5)` |
| Verb | `VERB`, `AUX` | `rgba(84, 103, 43, 0.92)` | `rgba(170, 184, 110, 0.5)` |
| Modifier | `ADJ`, `ADV`, `DET` | `rgba(69, 49, 109, 0.92)` | `rgba(160, 138, 220, 0.5)` |
| Function | `ADP`, `PART`, `SCONJ`, `CCONJ` | `rgba(59, 67, 75, 0.92)` | `rgba(150, 156, 166, 0.5)` |
| Fallback | anything ungrouped | `rgba(47, 50, 56, 0.92)` | `rgba(130, 134, 142, 0.5)` |

#### Metrics

| Element | Value |
| --- | --- |
| Row | row, wrap, align to baseline (`flex-end`), gap 8 |
| Chip box | border 1, radius 12 (`Spacing.two + Spacing.one`) |
| Chip padding | 10 horizontal (`Spacing.two + Spacing.half`), 2 vertical |
| Chip shadow | `0 1px 3px rgba(0, 0, 0, 0.35)` |
| Chip text | 24 / 32 / weight 600, theme `text`, content font |
| Phonetic (above) | 12 / 16, `textMuted`, margin-bottom 2, content font, single line |
| Transliterated (below) | 13 / 18 / weight 400, `textMuted`, margin-top 2 |
| Subtitle text shadow | color `rgba(0, 0, 0, 0.9)`, offset 0 / 2, radius 8 |
| Selection ring | inset -4 on all sides, border 3 `chipSelectedBorder`, radius 15 |

The selection ring is drawn outside the box so selecting never changes the chip's
size. A chip with no distinct phonetic renders a single space to hold the row's
baseline.

Tapping a chip measures the row's bottom edge in window coordinates and opens the
lookup drawer anchored there, plus `LOOKUP_TOP_GAP` (10).

### Card body

Below the hero. Container padding: 16 horizontal, 16 top.

| Element | Value |
| --- | --- |
| Translation | 18 / 26 / weight 400, `textSecondary`, margin-bottom 16, padding-right 64 |
| Section block | margin-bottom 16, padding-right 64 |
| Section label | 13 / 18 / weight 700, letter spacing 1.4, `accent`, margin-bottom 4 |
| Section text | 17 / 24, theme `text` |

#### Tip card

| Element | Value |
| --- | --- |
| Container | row, centered, gap 16, radius 16, padding 16, margin-right 64, fill `surface` |
| Icon circle | 44 × 44, radius 22, fill `accentSoft` |
| Icon | `lightbulb.fill`, 20, `accent` |
| Label | 12 / 16 / weight 700, letter spacing 1.2, margin-bottom 2 — literal text `WORD TO NOTICE` |
| Text | 14 / 20, theme `textSecondary` |

The right padding of 64 on the translation, section and tip keeps them clear of
the rail.

### Action rail

Absolute, right 16, bottom `insets.bottom + BottomTabInset + Spacing.three`,
centered, gap 16.

| Element | Value |
| --- | --- |
| Icon circle | 48 × 48, radius 24, fill `railIcon`; active fill `accentSoft` |
| Icon | 22 (speaker active 24) |
| Icon tint | theme `text`; active `accent` |
| Label | 12 / 16, theme `textSecondary`, margin-top 4 |
| Hit slop | `Spacing.two` (8) |

| Button | Symbols | Label |
| --- | --- | --- |
| Favorite | `heart` / `heart.fill` | none |
| Listen | `speaker.wave.2.fill`, playing `stop.circle` | `Listen` |
| Known | `checkmark.circle` / `checkmark.circle.fill` | `Known` |

Card container padding-bottom is `insets.bottom + BottomTabInset`.

### Screen chrome

Floating header at `insets.top + Spacing.two`, left and right 16, row,
space-between.

| Element | Value |
| --- | --- |
| Buttons | `CircleButton`, blur 25, fill `heroControl` |
| Back | `chevron.left`, navigates to `/dictionary` |
| Mute | `speaker.wave.2.fill` / `speaker.slash.fill` |
| Auto-advance | `play.fill` / `pause.fill`, tinted `accent` while running |
| Actions gap | 8 |

### Screen states

| State | Content |
| --- | --- |
| Error | `subtitle` "The feed could not load" + retry button |
| Empty | `subtitle` "Nothing to review" + `textSecondary` "Add words or seed the dictionary to fill the feed." |

| Element | Value |
| --- | --- |
| Container | centered, gap 8, padding 24 |
| Retry | margin-top 8, padding 24 horizontal / 8 vertical, radius 16, fill `accentSoft` |
| Retry label | weight 600, `accent` |
| Retry pressed | `opacity: 0.7` |

### Paging and playback timing

| Constant | Value |
| --- | --- |
| `itemVisiblePercentThreshold` | 60 |
| `AUTO_PRONOUNCE_DELAY_MS` | 200 |
| `TRANSLATION_DELAY_MS` | 100 |
| `AUTO_ADVANCE_DELAY_MS` | 1000 |
| `LOAD_AHEAD` | 5 cards |
| `PREFETCH_AHEAD` | 2 hero images |
| `LOOKUP_TOP_GAP` | 10 |

The list is `pagingEnabled` with `windowSize: 3`, `initialNumToRender: 1`,
`maxToRenderPerBatch: 2`. Auto-advance keeps the screen awake while running.

## Add card

Source: `src/features/add-card/` — `lib/add-card-theme.ts`,
`screens/add-card-screen.tsx`, `components/title-options-sheet.tsx`.

Three paged tabs (Translate, Photo, Manual) under a sliding tab bar. Only
Translate is built; the other two are placeholders.

### Palette

`AddCardColors`. Source comment: kept out of the theme tokens while the flow's
design is still settling.

| Token | Value |
| --- | --- |
| `background` | `#111318` |
| `primary` | `#4a6bd1` |
| `primaryRing` | `rgba(74, 107, 209, 0.28)` |
| `primaryBorder` | `rgba(74, 107, 209, 0.55)` |

Screen-local `Palette`, "matched to the reference design":

| Token | Value |
| --- | --- |
| `background` | `#111318` (from `AddCardColors`) |
| `surface` | `#1a1f27` |
| `surfaceBorder` | `rgba(255, 255, 255, 0.08)` |
| `inputBackground` | `#0f141c` |
| `inputBorder` | `rgba(74, 107, 209, 0.55)` |
| `primary` | `#4a6bd1` |
| `primaryRing` | `rgba(74, 107, 209, 0.28)` |
| `textSecondary` | `#8e949e` |

### Layout

| Element | Value |
| --- | --- |
| Screen | fill `background`, padding 16 horizontal |
| Top padding | `insets.top + Spacing.two` (8) |
| Bottom padding | `max(keyboardHeight, insets.bottom + BottomTabInset) + Spacing.three` |
| Header | `ScreenHeader` title "Add card", `backgroundColor: Palette.background`, margin-bottom 16 |
| Tabs | margin-bottom 24 |

The bottom padding follows the keyboard frame by frame; while the keyboard is
below the tab bar (closed or mid-flight) the tab-bar inset wins.

#### Tabs

`GlassSlidingTabs` (metrics in [Navigation and shared chrome](#navigation-and-shared-chrome)) with tints declared here:

| Property | Value |
| --- | --- |
| Active tint | `#fa5d7d` |
| Inactive tint | `#EBEBF0` |

| Tab id | Label | Symbol |
| --- | --- | --- |
| `translate` | Translate | `translate` |
| `photo` | Photo | `camera` |
| `manual` | Manual | `square.and.pencil` |

Tapping a non-adjacent tab jumps to the adjacent page without animation first,
then animates one page, so the intermediate page is skipped.

### Translate tab

#### Input

| Property | Value |
| --- | --- |
| Min height | 136 (`4 * 26 + 2 * Spacing.three`, i.e. 4 lines plus padding) |
| Border | 1, `inputBorder` |
| Radius | 16 |
| Fill | `inputBackground` |
| Padding | 16 |
| Text | 18 / 26 / weight 500, `#ffffff` |
| Placeholder color | `textSecondary` |
| Placeholder | "Input a sentence in your language – get native ways to say it." |
| Behaviour | multiline, `textAlignVertical: 'top'` |

#### Action row

Row, space-evenly, padding-top 16, margin-bottom 24.

| Element | Value |
| --- | --- |
| Side button | 64 × 64, radius 32, fill `surface`, border 1 `surfaceBorder` |
| Side icon | 26, `#ffffff` |
| Side label | 14 / 20 / weight 500, `textSecondary`, gap 8 below the button |
| Dictate ring | 104 × 104, radius 52, border 2 `primaryRing` |
| Dictate button | 88 × 88, radius 44, fill `primary` |
| Dictate icon | `mic.fill`, 38, `#ffffff` |
| Pressed | `opacity: 0.7` |

| Button | Symbol | Label |
| --- | --- | --- |
| Camera | `camera.fill` | Camera |
| Dictate | `mic.fill` | none |
| Paste | `doc.on.clipboard` | Paste |

Camera and Paste have no handlers yet.

#### Create button

| Property | Value |
| --- | --- |
| Min height | 54 |
| Radius | 16 |
| Padding | 24 horizontal |
| Fill | `primary` |
| Label | 17 / 22 / weight 600, `#ffffff`, text "Create" |
| Busy | `ActivityIndicator` in `#ffffff` |
| Pressed or disabled | `opacity: 0.7` |

Enabled when the trimmed input is non-empty and no generation is running.

### Photo and Manual tabs

| Element | Value |
| --- | --- |
| Container | centered, gap 16, padding 64 vertical |
| Icon | `camera` or `square.and.pencil`, 40, `primary` |
| Title | 20 / weight 600 — "Add from a photo" or "Add manually" |
| Text | `textSecondary` — "Coming soon" |

### Title options sheet

Opens after generation. Sheet-local `Palette`:

| Token | Value |
| --- | --- |
| `sheetBackground` | `#111318` |
| `surface` | `#22262e` |
| `surfacePressed` | `#30353e` |
| `surfaceBorder` | `#ffffff12` |
| `divider` | `#ffffff1f` |
| `primary` | `#4a6bd1` |
| `textPrimary` | `#ffffff` |
| `textSecondary` | `#9aa0a8` |
| `radioIdle` | `#8e949e` |
| `star` | `#f5c542` |
| `ripple` | `rgba(255, 255, 255, 0.12)` |

`SheetMaxHeightRatio` is 0.9.

#### Header

| Element | Value |
| --- | --- |
| Container | row, gap 12, padding 16 horizontal, 12 top, 8 bottom |
| Bottom border | hairline, `surfaceBorder` |
| Buttons | 44 × 44, radius 22, clipped |
| Button surface | `GlassView` `glassEffectStyle="regular"`, `colorScheme="dark"`, fill `surface` |
| Confirm button | same, tinted `primary`, fill `primary` |
| Close glyph | `xmark`, 17, `textPrimary` |
| Confirm glyph | `checkmark`, 17, weight semibold, `textPrimary` |
| Title | 17 / weight 600, centered, `textPrimary` — "Pick a phrasing" |
| Pressed or disabled | `opacity: 0.65` |

#### Option cards

List padding: 20 horizontal, 16 top, 24 bottom, gap 12.

| Element | Value |
| --- | --- |
| Card | padding 18 horizontal / 16 vertical, radius 16 continuous, border 1 `surfaceBorder`, fill `surface` |
| Selected | border `primary` |
| Pressed (non-Android) | fill `surfacePressed` |
| Option header | row, gap 8 |
| Tone label | 14 / weight 600, colored per tone |
| Recommended badge | `star.fill`, 13, `star` |
| Radio | `circle` / `circle.inset.filled`, 26; `radioIdle` idle, `primary` selected |
| Title row | row, gap 10, margin-top 6 |
| Speaker | 18 × 26 tap area, `speaker.wave.2` 18, `textSecondary` |
| Option title | 20 / weight 600, `textPrimary`, content font |
| Subtitle | 14, `textSecondary`, margin-top 8 |
| Note divider | hairline, `divider`, margin 10 vertical |
| Note | 12 / weight 300, `textSecondary` |

Tone colors:

| Tone | Label | Color |
| --- | --- | --- |
| `formal` | Formal | `#7ee787` |
| `polite` | Polite | `#79c0ff` |
| `casual` | Casual | `#f0883e` |
| `slang` | Slang | `#c084fc` |

Selecting an option fires `Haptics.ImpactFeedbackStyle.Light`; re-tapping the
already-selected option does nothing.

### Error messages

Shown in an `Alert` titled "Could not create titles":

| Code | Message |
| --- | --- |
| `invalid_request` | That text could not be processed. Try rephrasing it. |
| `server_misconfigured` | Title generation is not set up on the server. |
| `invalid_model_output` | The generated titles were unusable. Try again. |
| `provider_failed` | The language model did not respond. Try again. |
| `invalid_response` | Unexpected response from the server. |
| `unauthorized` | Title generation is not authorized. |
| `not_found` | Title generation is not available on this server. |
| `rate_limited` | Too many title requests. Wait a moment and try again. |
| `timeout` | Title generation took too long. Try again. |
| `server_failed` | The title service is temporarily unavailable. |
| `network_failed` | Could not reach the server. Check your connection. |

## Settings

Source: `src/features/settings/components/settings-ui.tsx` and
`src/features/settings/screens/` — `settings-screen.tsx`, `general-screen.tsx`,
`interface-screen.tsx`, `languages-screen.tsx`, `learning-screen.tsx`,
`sync-screen.tsx`.

A native iOS inset-grouped list. This feature uses its own palette and does not
share the `#111318` background the other screens use.

### Palette

`SettingsColors`, exported from `settings-ui.tsx`:

| Token | Value | Used for |
| --- | --- | --- |
| `background` | `#000000` | Screen and stack `contentStyle` |
| `card` | `#1C1C1E` | Section cards |
| `cardPressed` | `#2C2C2E` | Pressed row |
| `label` | `#FFFFFF` | Row labels |
| `separator` | `rgba(84, 84, 88, 0.6)` | Row separators |
| `chevron` | `rgba(235, 235, 245, 0.3)` | Disclosure chevrons |
| `textSecondary` | `rgba(235, 235, 245, 0.6)` | Detail values, section headers and footers |
| `checkmark` | `#0A84FF` | Selection checkmarks |

### Metrics

Source comment: "Native iOS inset-grouped list metrics (matches Settings.app / Telegram)."

| Constant | Value |
| --- | --- |
| `RowMinHeight` | 52 |
| `IconTileSize` | 30 |
| `IconTileRadius` | 8 |
| `SectionRadius` | 26 |
| `RowGap` | 14 |
| `IconRowSeparatorInset` | 60 (`Spacing.three + IconTileSize + RowGap`) |

### Screen shell

Floating header over a scrolling list; content slides under the status bar and
title, dimmed by the veil, and the back button blurs it.

| Element | Value |
| --- | --- |
| Screen | fill `background` |
| Header top | `insets.top + Spacing.two` (8) |
| Chrome height | `headerTop + ScreenHeaderHeight` (44) |
| Content top padding | `chromeHeight + Spacing.four` (24) |
| Content bottom padding | `BottomTabInset + insets.bottom + Spacing.five` (32) |
| Content | padding 16 horizontal, gap 24 between sections |
| Scroll indicator inset | `top: chromeHeight` |
| Veil | `HeaderVeil` at `chromeHeight` (see [Navigation and shared chrome](#navigation-and-shared-chrome)) |
| Overlay | absolute, left/right 0, padding 16 horizontal |

### Section

| Element | Value |
| --- | --- |
| Card | fill `card`, radius 26, continuous, clipped |
| Header text | 13 / 18, `textSecondary`, margin-bottom 8, margin-left 16, **uppercased** |
| Footer text | 13 / 18, `textSecondary`, margin-top 8, margin 16 horizontal |
| Separator | `StyleSheet.hairlineWidth`, `separator`, left inset from `separatorInset` |

`separatorInset` defaults to `Spacing.three` (16) and is passed as
`IconRowSeparatorInset` (60) for sections whose rows carry icon tiles.

### Row

| Element | Value |
| --- | --- |
| Row | min height 52, row, centered, padding 16 horizontal, gap 14 |
| Icon tile | 30 × 30, radius 8, continuous, fill from `iconBackground` |
| Icon | default size 18, weight medium, `#ffffff` |
| Label | 17 / 22 / weight 400, `label`, `flex: 1` |
| Value | 17 / 22, `textSecondary` |
| Chevron | `chevron.right`, 14, weight semibold, `chevron` |
| Checkmark | `checkmark`, 17, weight semibold, `checkmark` |
| Pressed | fill `cardPressed` |

Source comment on the label: "iOS list row label metrics: 17pt regular."
Rows with no handler and no chevron render as a plain view (not pressable);
chevron rows stay pressable even before their destination exists.

### Settings index

Sections top to bottom.

#### Learning language section

Header: translated `learning.learningLanguage.label`. One row per enrolled
language labeled `"<emoji> <name>"`, with a `checkmark` on the active one, then
a final row "Add" or "Manage" (depending on whether any language remains
unenrolled) with a chevron to `/settings/languages`.

#### Icon rows

All four groups use `separatorInset: IconRowSeparatorInset` (60).

| Row | Symbol | Icon tile color | Icon size | Destination |
| --- | --- | --- | --- | --- |
| My profile | `person.crop.circle.fill` | `#EB4E3D` | 18 | none |
| General | `gearshape.fill` | `#8E8E93` | 18 | `/settings/general` |
| Interface | `paintbrush.fill` | `#5AC8FA` | 16 | `/settings/interface` |
| Learning | `graduationcap.fill` | `#3478F6` | 15 | `/settings/learning` |
| Sync | `externaldrive.fill` | `#34C759` | 18 | `/settings/sync` |
| Dev | `hammer.fill` | `#FF9500` | 18 | `/settings/dev` |
| Terminal | `terminal.fill` | `#636366` | 18 | `/settings/terminal` |
| FAQ | `questionmark` | `#FF9500` | 15 | none |
| Features | `sparkles` | `#AF52DE` | 18 | none |

Group boundaries: [My profile] · [General, Interface, Learning, Sync] ·
[Dev, Terminal] · [FAQ, Features].

The Learning row shows the active learning language's name as its `value`.

### Sub-screens

All use `SettingsScreenShell` with `onBack={router.back}`.

#### General

One section, one row: Native language, showing `"<emoji> <name>"` as its value.
Informational only — picked at onboarding, English only for now.

#### Interface

One section with footer `autoplayPronunciation.description`. One row, "Autoplay
pronunciation", trailing a SwiftUI `Toggle` with `labelsHidden()`.

Source comment: RN's `Switch` mis-measures the larger iOS 26 control and
overflows the row, so the SwiftUI `Toggle` is used instead.

#### Languages

One section with footer `languages.description`. One row per supported learning
language labeled `"<emoji> <name>"`, each trailing a SwiftUI `Toggle`. The active
language's toggle is `disabled()`, so it cannot be turned off — which also keeps
at least one language enrolled. Turning a language on makes it active.

#### Learning

Title is `learning.title` interpolated with the active language's name.

1. A section with one row, "Knowledge level", trailing a SwiftUI `Picker` with
   `pickerStyle('menu')`. Options: `beginner`, `intermediate`, `advanced`.
2. A writing-display-mode section with header `learning.writingDisplayMode.label`
   and footer `learning.writingDisplayMode.description`, one radio row per
   available mode with a `checkmark` on the selected one. Hidden entirely when
   the language has fewer than two available modes.

Mode labels are built by joining the per-language layer labels with `" + "`,
never a translated phrase per combination.

#### Sync

Two sections, one for audio and one for photos. Each has a footer and two rows:

1. An offline toggle (SwiftUI `Toggle`, `labelsHidden()`).
2. A removal row whose label interpolates the on-disk size, formatted as
   `"<n.n> MB"` (bytes / 1024 / 1024, one decimal place).

Size refreshes every `SIZE_REFRESH_MS` (2000) while the screen is focused.
Removal opens a confirm `Alert` with a `cancel` and a `destructive` action.

## Word lookup

Source: `src/features/word-lookup/components/lookup-content.tsx`.

The drawer that opens when a breakdown chip is tapped in the feed. It is content
for the shared `BottomSheet` (chrome and motion in [Navigation and shared chrome](#navigation-and-shared-chrome)), anchored
to the bottom edge of the chip row plus 10.

It borrows `FeedColors` rather than declaring a palette, and adds two tag colors.

| Token | Value |
| --- | --- |
| `TAG_BLUE` | `#5B7CFA` |
| `TAG_RED` | `#E0645A` |
| Divider | `rgba(255, 255, 255, 0.18)` |
| Speaker button fill | `rgba(255, 255, 255, 0.08)` |

### Header

Rendered into the sheet's header slot.

| Element | Value |
| --- | --- |
| Container | gap 16, padding-bottom 8 |
| Row | row, align to top, gap 8, padding-right 38 (`30 + Spacing.two`, clears the close button) |
| Icon | `character.book.closed`, 20, `FeedColors.chipSelectedBorder` `#E8C158`, margin-top 4 |
| Text | 20 / 28 / weight 500, theme `text`, `flex: 1` |
| Divider | hairline, `rgba(255, 255, 255, 0.18)` |

The header text is the word's in-context translation (falling back to the first
alternative), with its first character upper-cased.

### Body

Container gap is 16 throughout.

| Element | Value |
| --- | --- |
| Details | 16 / 22 / weight 300, theme `text` |
| Word row | row, centered, gap 16 |
| Word | 34 / 44 / weight 700, theme `text`, content font |
| Speaker (word) | 48 × 48, radius 24, fill `rgba(255, 255, 255, 0.08)` |
| Speaker (base form) | 32 × 32, radius 16, same fill |
| Speaker glyph | `speaker.wave.2.fill` at `size * 0.42`, active `size * 0.5`, `#FFFFFF` |
| Base form row | row, centered, gap 8 |
| Base form | 15 / 20, theme `textSecondary`, prefix literal `Base form: `, the term itself in the content font |

#### Tags

| Element | Value |
| --- | --- |
| Row | row, wrap, gap 8 |
| Tag | border 1 in the tag color, radius 8, padding 8 horizontal / 2 vertical |
| Tag text | 14 / 18, same color as the border |

Three tags, in order:

1. JLPT level — hardcoded to `N-3`, per the source: "JLPT level is not in the
   data yet; hardcoded per design." `TAG_BLUE`.
2. Part of speech, lower-cased. `TAG_BLUE`.
3. `TOP-<frequencyRank>`, only when a rank exists. `TAG_RED`.

#### Meanings

| Element | Value |
| --- | --- |
| List | gap 4 |
| Row | row, aligned to baseline, gap 8 |
| Index | 17 / 26 / weight 400, theme `textSecondary`, rendered as `"1."` |
| Text | 19 / 26 / weight 400, theme `text`, `flex: 1` |

The list is the in-context translation followed by the other translations, with
empty entries filtered out. Dividers (hairline, `rgba(255, 255, 255, 0.18)`) sit
after the details block, after the base-form block, and after the meanings block.

The base-form row only renders when a base form exists and differs from the
original word.

The sheet's footer slot currently renders the literal placeholder text `footer`.

## Player

Source: `src/features/player/screens/player-screen.tsx`.

A stub. The whole screen is:

| Element | Value |
| --- | --- |
| Container | `ThemedView`, `flex: 1`, centered both axes |
| Content | `ThemedText` default type — literal text "Player — coming soon" |

It inherits the default theme background `Colors.dark.background` `#151c26` and
the default text color `#ffffff` at 16 / 24 / weight 500. It declares no colors,
no spacing, and no other metrics.

Its tab entry is listed in [Navigation and shared chrome](#navigation-and-shared-chrome): `play.circle` / `play.circle.fill`,
label "Player".

The screen logs a visit on focus and does nothing else.

## Dev tools

Source: `src/features/dev/terminal-view.tsx`, `dev-view.tsx`.

Two developer screens reached from the Settings index. Both reuse
`SettingsColors` (see [Settings](#settings)) rather than declaring a palette, and both
use `ScreenHeader` with `backgroundColor: SettingsColors.background`.

### Terminal

An in-app console log viewer.

#### Level colors

| Level | Color |
| --- | --- |
| `log` | `#EBEBF5` |
| `info` | `#64D2FF` |
| `debug` | `#AEAEBA` |
| `warn` | `#FFD60A` |
| `error` | `#FF6961` |

#### Metrics

| Element | Value |
| --- | --- |
| Screen | fill `SettingsColors.background` `#000000`, top padding `insets.top + Spacing.two` |
| Header | padding 16 horizontal |
| Clear button | min height 44, padding 8 horizontal |
| Clear label | 16, `SettingsColors.checkmark` `#0A84FF` |
| Dimmed (nothing to clear) | `opacity: 0.4` |
| Filter row | gap 8, padding 16 horizontal, 16 vertical |
| Filter chip | min height 44, padding 16 horizontal, radius 12, fill `SettingsColors.card` `#1C1C1E`, border 1 transparent |
| Selected filter | border `#0A84FF`, fill `#11243A` |
| Filter label | `Fonts.mono`, 12, weight 600 |
| Description | 12, `SettingsColors.textSecondary`, margin 16 horizontal, 16 bottom |
| Empty | `SettingsColors.textSecondary`, centered, margin-top 32 |
| Entry row | padding 16, gap 8, bottom border hairline `SettingsColors.separator` |
| Metadata | `Fonts.mono`, 11, `SettingsColors.textSecondary` |
| Message | `Fonts.mono`, 12 / 18, colored by level |

Filters are `all` plus each console level.

### Dev

| Element | Value |
| --- | --- |
| Destructive button fill | `#B3261E` |
| Its label | `#ffffff` |
| `DuplicateCopies` | 40 |

`duplicate-cards.ts` tags generated rows with `dev:duplicate` and inserts them in
chunks of 200. The screen otherwise reuses the settings row and section styles.

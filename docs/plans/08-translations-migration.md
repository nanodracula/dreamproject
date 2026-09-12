# Translations migration plan

Status: implemented September 13, 2026. Catalog migration and message-output
verification are complete; iOS visual inspection and future screen integration
remain deferred.

Source: `/Users/vlad/Documents/My/Projects/Sites/dreamproject/src/i18n/`.
Target: `apps/ios/DreamApp/Resources/Localization/`.
Related: [language configuration](06-language-config.md), especially §7.

Migrate the existing English and Ukrainian interface translations into native
String Catalogs organized by feature, using Xcode-generated Swift symbols and
no additional localization library. Import the translations now; connect them to feature
screens as those screens are built. The current Swift UI contains only the
placeholder `RootView`.

## 1. Inventory the existing translations

Read these files in the source project:

- `src/i18n/locales/en/common.ts`
- `src/i18n/locales/uk/common.ts`
- `src/i18n/locales/en/settings.ts`
- `src/i18n/locales/uk/settings.ts`

Compare language keys and interpolation placeholders. Inspect consumers,
including dynamically constructed keys for dictionary tabs, regeneration,
settings items, knowledge levels, and writing layers.

Account for every existing translation, including accessibility labels.
The `common:home.title` greeting and five `common:database.*` diagnostic
messages are excluded at the user's request; the Settings developer and
terminal labels remain in scope.
Preserve wording during migration. Report missing translations or mismatched
placeholders instead of silently dropping entries or inventing replacements.

## 2. Choose stable catalog keys

Use flat camelCase keys within feature tables. The catalog filename supplies
the generated Swift namespace, so omit redundant `dictionary` and `settings`
key prefixes. Omit redundant nesting segments when the meaning remains clear;
for example, use `Settings.knowledgeLevelBeginner` for the beginner option.

| Existing namespace and key | Catalog | Key |
| --- | --- | --- |
| `common:dictionary.title` | `Dictionary` | `title` |
| `common:dictionary.tabs.words` | `Dictionary` | `tabsWords` |
| `common:dictionary.selection.count` | `Dictionary` | `selectionCount` |
| `common:dictionary.counts.words.*` | `Dictionary` | `countsWords` |
| `settings:title` | `Settings` | `title` |
| `settings:learning.knowledgeLevel.options.beginner` | `Settings` | `knowledgeLevelBeginner` |

Keep an explicit source-to-catalog mapping during conversion so completeness
can be checked after plural keys are collapsed. Check for collisions,
including normalization of segments such as `zh-Hant`. Keep independently
meaningful messages separate even when their English values match.

## 3. Organize String Catalogs by feature

Keep these catalogs together in `Resources/Localization/`, with English as
the source language and Ukrainian as the additional localization in each:

```text
Dictionary.xcstrings   // Dictionary interface
Settings.xcstrings     // Settings interface
```

These are distinct tables in the existing app bundle. The folder organizes
files; it does not introduce a module or resource bundle.

- Store both languages together in each catalog.
- Mark imported entries as manually managed so translations for upcoming
  screens remain available before they have Swift call sites.
- Add comments only when they clarify ambiguous wording or placeholder
  meaning. Omit generic descriptions and old TypeScript source references.
  Retain `extractionState`, translation `state`, and plural variations.
- Preserve known review status honestly. Existing translation presence does
  not establish that a linguistic review happened; flag known uncertainties.

This is a one-time conversion. Maintain iOS translations in the catalogs
afterward; no ongoing synchronization with the old TypeScript files is needed.
Leave the old project unchanged. Do not add a permanent conversion framework
or split catalogs by size; boundaries follow features that change independently.

## 4. Convert interpolation and plurals

Replace i18next interpolation with typed catalog placeholders, retaining
descriptive argument names.

| Existing placeholder | Intended Swift argument |
| --- | --- |
| `{{language}}` | `language: String` |
| `{{title}}` | `title: String` |
| `{{total, number}}` | `total: Int` |
| `{{size}}` | `size: String` |

The conversion uses named `%(name)@` string placeholders and `%(name)lld`
integer placeholders. Other imported arguments are `month: String`,
`kind: String`, `done: Int`, and `succeeded: Int`. Xcode 26.6 generates the
intended argument labels and types directly, including native number grouping.

Inspect each consumer to confirm argument types. Preserve localized number
formatting, including grouping where the old `number` formatter provides it;
do not assume replacing a numeric placeholder with a plain string or integer
format automatically preserves that behavior. Keep numeric values available
for plural selection. Translators must retain control over argument order.

Collapse each dictionary count family (`all`, `words`, `phrases`, `favorites`,
and `drafts`) into one catalog entry with plural variations. Preserve English
`one`/`other` and Ukrainian `one`/`few`/`many`/`other` translations. iOS selects
the plural form; do not port `src/i18n/plural.ts`.

Intended usage after configuring and verifying generated signatures:

```swift
Text(.Dictionary.title(language: languageName))
Text(.Dictionary.selectionCount(total: selectedCount))
Text(.Dictionary.countsWords(total: wordCount))
Text(.Settings.knowledgeLevelBeginner)
```

Messages containing numbers but no grammatical variation, such as the
existing selection summary, remain ordinary interpolated messages.

## 5. Configure Xcode

Update `apps/ios/DreamApp.xcodeproj/project.pbxproj`:

- Add Ukrainian to the project's localizations.
- Keep English as the development language.
- Explicitly enable Generate String Catalog Symbols for the app target.
- Keep localization extraction enabled and confirm the catalogs are included
  in the app target's resources.

The placeholder `RootView` has no greeting text. No localization manager,
startup initialization, third-party dependency, or manually maintained
generated-accessor file is needed. Connect the catalog symbols when the
dictionary and settings screens are built.

## 6. Integrate future feature screens

These conventions apply when each feature is ported; building those screens
is outside this migration's immediate scope.

- Use generated symbols for labels, alerts, navigation, and accessibility
  text.
- Replace dynamic string-key construction with explicit enum mappings or
  typed resource properties. The selected dictionary tab chooses its count
  message; iOS chooses that message's plural form.
- Keep presentation mappings alongside the feature UI rather than in Core
  models or a global localization service.
- Accept `LocalizedStringResource` in reusable components that receive
  localized UI text. Resolve to `String` only where an API needs one.
- Render database words, sentences, and generated translations as content,
  without using them as catalog lookup keys.

The interface follows native iOS app-language selection. Learning content
continues to use `UserSettings.nativeLanguage` and
`UserSettings.activeLearningLanguage` independently. Do not introduce a new
interface-language account setting.

Localizing language names currently hardcoded in the old language
configuration is a separate addition coordinated with plan 06. This plan
copies existing interface translations; it does not change backend prompts,
language codes, content storage, or speech configuration.

## 7. Verification

Perform a one-time source/catalog comparison without adding tests:

- Account for every source key in the mapping, including collapsed plural
  variants and strings for screens not yet implemented, with
  `common:home.title` and the five `common:database.*` messages explicitly
  excluded.
- Compare English and Ukrainian values, allowing only the intended
  placeholder and plural representation changes.
- Check placeholder types, argument names, plural coverage, and key/symbol
  collisions.
- Build the app to verify catalog compilation and generated Swift symbols.

During this migration, resolve representative catalog messages in English
and Ukrainian and verify unsupported-language fallback to English,
interpolation, and plural output for counts such as `0`, `1`, `2`, `5`, `11`,
`21`, and `22`. Check a larger count such as `12345` for localized number
formatting. Use a one-time verification script or temporary preview; do not
wait for dictionary and settings screens to exist to check message output.

Defer wrapping, truncation, and placement checks for future feature screens
until those screens are built.
Ask before opening the iPhone simulator. Do not add tests unless the user
requests them.

## 8. Completion criteria

The immediate migration is complete when all in-scope translations are
accounted for across the two catalogs, native localization is configured,
generated symbols compile, and representative translated message output is
verified. Report any unresolved translation discrepancies or deferred screen
layout checks.

Connecting dictionary and settings translations to their Swift screens
belongs to those screen migrations. No old-project edits, commits, or pushes
are part of this plan.

## 9. Implementation record

The original migration and four-catalog verification below preceded the
user-requested removal of the developer diagnostics and placeholder greeting.

- Imported all 123 English and 133 Ukrainian source values into 118 manually
  managed catalog entries. The difference in source counts is the additional
  Ukrainian plural forms across the five count families. No missing keys,
  placeholder mismatches, or key/symbol collisions were found.
- Preserved every source value, changing only placeholder syntax and plural
  representation. The source-to-catalog mapping was checked during conversion;
  source references and generic comments are not stored in the catalogs.
  Shortened redundant settings nesting and expanded `a11y` to `accessibility`
  for readable generated symbols; `zh-Hant` becomes `ZhHant` in those symbols.
- Retained supplied translations as translated entries; no new linguistic
  review is claimed. The Ukrainian `Dev` and `Terminal` labels remain in
  English exactly as supplied by the source.
- Initially organized 118 entries under `Resources/Localization/`:
  `Localizable` (1), `Dictionary` (59), `Settings` (53), and `Developer` (5).
  Removed redundant dictionary/settings key prefixes and retained 11 useful
  placeholder comments. All translation values, states, and plural variations
  were unchanged.
- Added Ukrainian to the project and enabled symbol generation in Debug and
  Release. The existing synchronized app folder includes the catalogs as
  resources automatically. Initially connected the greeting in `RootView`.
- Unsigned Debug and Release builds for generic iOS passed with Xcode 26.6,
  including catalog compilation and compilation of all generated symbols.
- Verified all 256 source-to-catalog values with a one-time comparison and
  confirmed 118 unique generated accessors. Conversion and verification
  scripts stayed outside the repository; no permanent tooling or tests were
  added.
- Resolved the iOS build's compiled catalog resources through the generated
  accessors in a temporary macOS Foundation executable: 306 English/Ukrainian
  message checks covered every accessor, all five plural families at `0`,
  `1`, `2`, `5`, `11`, `21`, `22`, and `12345`, all interpolation arguments,
  and localized grouping (`12,345` / `12 345`). Another 50 checks verified
  native English fallback with French-only language preferences, including
  the greeting and plural selection. Fallback was checked through native
  bundle language negotiation, not by forcing an unsupported resource locale.
- Repeated the build and all 356 message checks after splitting the catalogs.
  That app bundle contained all four tables in both languages, with plural
  resources only for Dictionary and no old Localizable plural resource.
- Subsequently removed `Developer.xcstrings` and its five unused
  `common:database.*` diagnostics at the user's request. That left
  113 entries: `Localizable` (1), `Dictionary` (59), and
  `Settings` (53). The Settings developer and terminal labels remain.
- After Developer removal, an unsigned Debug build for generic iOS passed
  and the built app was confirmed to contain no Developer table resources.
- Then removed `Localizable.xcstrings` and its `common:home.title` greeting
  at the user's request, including the greeting text in `RootView`. The
  current catalog set contains 112 entries: `Dictionary` (59) and
  `Settings` (53).
- After Localizable removal, an unsigned Debug build for generic iOS passed.
  The built English and Ukrainian resources each contain only
  `Dictionary.strings`, `Dictionary.stringsdict`, and `Settings.strings`;
  no Swift references to the removed symbols remain.
- No simulator was opened. Message resolution was verified on macOS
  Foundation; screen wrapping, truncation, and placement remain part of the
  corresponding feature-screen work.

# Translations migration plan

Status: planned, not implemented, September 13, 2026.

Source: `/Users/vlad/Documents/My/Projects/Sites/dreamproject/src/i18n/`.
Target: `apps/ios/DreamApp/Resources/Localizable.xcstrings`.
Related: [language configuration](06-language-config.md), especially §7.

Migrate the existing English and Ukrainian interface translations into one
native String Catalog, using Xcode-generated Swift symbols and no additional
localization library. Import the translations now; connect them to feature
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

Account for every existing translation, including accessibility labels and
developer-screen text. Preserve wording during migration. Report missing
translations or mismatched placeholders instead of silently dropping entries
or inventing replacements.

## 2. Choose stable catalog keys

Use flat camelCase keys with feature prefixes. Remove the generic `common`
namespace and retain the `settings` prefix for settings messages.

| Existing namespace and key | Catalog key |
| --- | --- |
| `common:home.title` | `homeTitle` |
| `common:dictionary.title` | `dictionaryTitle` |
| `common:dictionary.tabs.words` | `dictionaryTabsWords` |
| `common:dictionary.selection.count` | `dictionarySelectionCount` |
| `common:dictionary.counts.words.*` | `dictionaryCountsWords` |
| `settings:title` | `settingsTitle` |
| `settings:learning.knowledgeLevel.options.beginner` | `settingsLearningKnowledgeLevelBeginner` |

Keep an explicit source-to-catalog mapping during conversion so completeness
can be checked after plural keys are collapsed. Check for collisions,
including normalization of segments such as `zh-Hant`. Keep independently
meaningful messages separate even when their English values match.

## 3. Create one String Catalog

Add `Resources/Localizable.xcstrings` to the Swift app, containing English as
the source language and Ukrainian as the additional localization.

- Store both languages in the same catalog.
- Mark imported entries as manually managed so translations for upcoming
  screens remain available before they have Swift call sites.
- Preserve useful existing comments and add context for ambiguous labels,
  placeholders, and accessibility messages.
- Preserve known review status honestly. Existing translation presence does
  not establish that a linguistic review happened; flag known uncertainties.

This is a one-time conversion. Maintain iOS translations in the catalog
afterward; no ongoing synchronization with the old TypeScript files is needed.
Leave the old project unchanged. Do not add a permanent conversion framework
or split the catalog by size.

## 4. Convert interpolation and plurals

Replace i18next interpolation with typed catalog placeholders, retaining
descriptive argument names.

| Existing placeholder | Intended Swift argument |
| --- | --- |
| `{{language}}` | `language: String` |
| `{{title}}` | `title: String` |
| `{{total, number}}` | `total: Int` |
| `{{size}}` | `size: String` |

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
Text(.dictionaryTitle(language: languageName))
Text(.dictionarySelectionCount(total: selectedCount))
Text(.dictionaryCountsWords(total: wordCount))
```

Messages containing numbers but no grammatical variation, such as the
existing selection summary, remain ordinary interpolated messages.

## 5. Configure Xcode and connect the existing screen

Update `apps/ios/DreamApp.xcodeproj/project.pbxproj`:

- Add Ukrainian to the project's localizations.
- Keep English as the development language.
- Explicitly enable Generate String Catalog Symbols for the app target.
- Keep localization extraction enabled and confirm the catalog is included
  in the app target's resources.

Replace the placeholder greeting in `App/RootView.swift` with:

```swift
Text(.homeTitle)
```

Use the imported English and Ukrainian greeting values. No localization
manager, startup initialization, third-party dependency, or manually maintained
generated-accessor file is needed.

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
  variants and strings for screens not yet implemented.
- Compare English and Ukrainian values, allowing only the intended
  placeholder and plural representation changes.
- Check placeholder types, argument names, plural coverage, and key/symbol
  collisions.
- Build the app to verify catalog compilation and generated Swift symbols.

Visual verification should cover English and Ukrainian, unsupported-language
fallback to English, interpolation, and counts such as `1`, `2`, `5`, `11`,
and `21`. Check a larger count such as `12345` for localized number formatting.
Inspect the existing greeting immediately; exercise feature messages through
previews or their screens as those become available. Ask before opening the
iPhone simulator. Do not add tests unless the user requests them.

## 8. Completion criteria

The immediate migration is complete when all existing translations are
accounted for in one catalog, native localization is configured, generated
symbols compile, and the existing greeting uses them. Report any unresolved
translation discrepancies or deferred visual checks.

Connecting dictionary and settings translations to their Swift screens
belongs to those screen migrations. No old-project edits, commits, or pushes
are part of this plan.

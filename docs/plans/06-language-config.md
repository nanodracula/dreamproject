# Language configuration plan

Status: planned, not implemented, September 12, 2026.
Source: `dreamproject-old` `shared/config/languages.ts` and
`shared/config/writing-display-mode.ts` at `effe870`.
Target: `apps/ios/DreamApp/Core/Models/LearningLanguage.swift`.
Related server changes are owned by the migration in plan 04 (§2).

Port the supported-language configuration to Swift and give it a single
owner. Today one file is imported by both the app and an edge function; after
this plan the app owns it outright and no edge function reads it.

## 1. Who actually needs the config

Audit of every consumer in the source project:

| Consumer | Uses |
| --- | --- |
| App (feed, dictionary, add card, word lookup, settings) | `getLearningLang`, `getSpeechConfig`, `nativeLangsConfig`, `contentFontFamily`, the writing-layer helpers |
| `generate-text/workflows/card-title.ts` | `getLearningLang(code).name`, and `LearningLangCode` as the key type of its `languageNotes` map |
| `shared/contracts/text-generation.ts` | `learningLangCodes`, to validate `learningLanguageCode` in the request |

The server's use of `name` is already redundant: the client sends the same
string in the request, as

```ts
nativeWritingSystem: `${language.name} (${language.writingVariants.standard.promptLabel})`
```

So the split is clean. **The client owns what a language is; the server owns
how to prompt about it.** The per-language prompt guidance in `languageNotes`
is prompt engineering and stays server-side.

## 2. The Swift file

One file, `Core/Models/LearningLanguage.swift`: the type, the table, native
languages, and the writing-layer rules. It all changes for the same reason —
a language is added — so it is not split.

`Core/` because this is Foundation-only data. Not `Config/`: that folder is
reserved by [plan 07](07-supabase-ios-integration.md) for build and environment values read
from an xcconfig, which change per configuration. This table is identical in
every build and carries domain rules (§3). `architecture.md` already reserves
the path and calls it "supported languages config, not a column type" — rows
still store `lang` as a plain string.

```swift
import Foundation

/// A language the app can teach. Configuration, not a column type: rows store
/// `lang` as a plain string.
nonisolated struct LearningLanguage: Identifiable, Equatable, Sendable {
    /// Identifies the language or writing system inside the app.
    let code: String
    /// The regional variant used for learning content and pronunciation.
    /// Dates and numbers use the user's runtime locale instead.
    let contentLocale: String
    let name: String
    let nativeName: String
    let emoji: String
    let writing: WritingVariants
    let speech: SpeechSettings
    /// Font family for learning content, or `nil` for the system font.
    /// Han-script languages need one: iOS picks CJK glyphs from the device's
    /// language list rather than from the text, so Traditional Chinese can be
    /// drawn with Japanese glyph forms. An explicit family is deterministic.
    let contentFontFamily: String?
    /// Cloud text-to-speech voice for generated audio; `nil` keeps playback
    /// on device.
    let cloudVoice: CloudVoice?

    var id: String { code }
}

/// English script names handed to text generation. User-facing labels are
/// localized separately.
nonisolated struct WritingVariants: Equatable, Sendable {
    let standard: String
    var phonetic: String?
    var transliterated: String?
}

nonisolated struct SpeechSettings: Equatable, Sendable {
    /// Fraction of the platform's normal speaking rate.
    var rate: Double = 0.8
    var pitch: Double = 1
    var volume: Double = 1
}

nonisolated struct CloudVoice: Equatable, Sendable {
    /// Key in the audio function's voice map.
    let name: String
    /// The provider's code for the language.
    let languageCode: String
}

extension LearningLanguage {
    static let all = [japanese, mandarinTraditional, korean, polish, ukrainian]

    static func with(code: String) -> LearningLanguage? {
        all.first { $0.code == code }
    }

    static let japanese = LearningLanguage(
        code: "ja", contentLocale: "ja-JP",
        name: "Japanese", nativeName: "日本語", emoji: "🇯🇵",
        writing: WritingVariants(standard: "Kanji and kana", phonetic: "Hiragana", transliterated: "Romaji"),
        speech: SpeechSettings(),
        contentFontFamily: "Hiragino Sans",
        cloudVoice: CloudVoice(name: "japanese_female_fumi", languageCode: "ja")
    )

    static let mandarinTraditional = LearningLanguage(
        code: "zh-Hant", contentLocale: "zh-TW",
        name: "Mandarin (Traditional)", nativeName: "繁體中文", emoji: "🇹🇼",
        writing: WritingVariants(
            standard: "Traditional Chinese",
            phonetic: "Zhuyin (Bopomofo)",
            transliterated: "Hanyu Pinyin with tone marks"
        ),
        speech: SpeechSettings(),
        contentFontFamily: "PingFang TC",
        cloudVoice: CloudVoice(name: "taiwanese_female_clear_voice_su", languageCode: "zh")
    )

    static let korean = LearningLanguage(
        code: "ko", contentLocale: "ko-KR",
        name: "Korean", nativeName: "한국어", emoji: "🇰🇷",
        writing: WritingVariants(standard: "Hangul", transliterated: "Revised Romanization of Korean"),
        speech: SpeechSettings(),
        contentFontFamily: nil,
        cloudVoice: nil
    )

    static let polish = LearningLanguage(
        code: "pl", contentLocale: "pl-PL",
        name: "Polish", nativeName: "Polski", emoji: "🇵🇱",
        writing: WritingVariants(standard: "Polish Latin alphabet"),
        speech: SpeechSettings(),
        contentFontFamily: nil,
        cloudVoice: nil
    )

    static let ukrainian = LearningLanguage(
        code: "uk", contentLocale: "uk-UA",
        name: "Ukrainian", nativeName: "Українська", emoji: "🇺🇦",
        writing: WritingVariants(standard: "Ukrainian Cyrillic", phonetic: "Pronunciation", transliterated: "Romanization"),
        speech: SpeechSettings(),
        contentFontFamily: nil,
        cloudVoice: nil
    )
}

/// A language the app's content is translated into.
nonisolated struct NativeLanguage: Identifiable, Equatable, Sendable {
    let code: String
    let name: String
    let nativeName: String
    let emoji: String

    var id: String { code }

    static let all = [english]
    static let english = NativeLanguage(code: "en", name: "English", nativeName: "English", emoji: "🇬🇧")
}
```

Two fields from the source are deliberately not ported:

- `LearningLang.voice`, the on-device voice override, is declared and unset by
  every language. Drop it; `AVSpeechSynthesisVoice(language:)` covers the case.
- `cloudVoice` is dead in the source too — nothing reads it, and
  `generate-audio` takes `voiceName` from its request body. Port it anyway:
  the identifiers cannot be recovered from anywhere else once the old
  repository is gone, and wiring it up is one call site.

## 3. Writing display modes

`writing-display-mode.ts` derives from language data, so its rules live on
`LearningLanguage` rather than beside `WritingDisplayMode` in
`Core/Models/UserSettings.swift`.

```swift
nonisolated enum WritingLayer: Sendable {
    case standard, phonetic, transliterated
}

extension WritingDisplayMode {
    /// Layers this mode shows; `standard` is always present.
    var layers: [WritingLayer] {
        switch self {
        case .standardOnly: [.standard]
        case .standardAndPhonetic: [.standard, .phonetic]
        case .standardAndTransliterated: [.standard, .transliterated]
        case .standardAndPhoneticAndTransliterated: [.standard, .phonetic, .transliterated]
        }
    }
}

extension LearningLanguage {
    /// Modes whose every layer this language declares.
    var availableWritingDisplayModes: [WritingDisplayMode] {
        WritingDisplayMode.allCases.filter { $0.layers.allSatisfy(declares) }
    }

    /// Drops the layers the language lacks, so the full mode becomes
    /// `.standardOnly` for Polish. Never write the result back.
    func normalized(_ mode: WritingDisplayMode) -> WritingDisplayMode {
        let layers = mode.layers.filter(declares)
        return WritingDisplayMode.allCases.first { $0.layers == layers } ?? .standardOnly
    }

    private func declares(_ layer: WritingLayer) -> Bool {
        switch layer {
        case .standard: true
        case .phonetic: writing.phonetic != nil
        case .transliterated: writing.transliterated != nil
        }
    }
}
```

Behaviour to preserve from the source: normalization never writes its result
back to storage, and an unknown stored mode resolves to `.standardOnly`.

## 4. Speech settings

`rate: 0.8` is a multiple of normal speaking rate, expo-speech's scale.
`AVSpeechUtterance.rate` is `0...1` with normal at
`AVSpeechUtteranceDefaultSpeechRate` (0.5), so assigning `0.8` directly gives
roughly double the intended speed. `pitch` and `volume` map one to one.

```swift
// Infrastructure/Speech/ — imports AVFoundation, so not Core.
let utterance = AVSpeechUtterance(string: text)
utterance.voice = AVSpeechSynthesisVoice(language: language.contentLocale)
utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(language.speech.rate)
utterance.pitchMultiplier = Float(language.speech.pitch)
utterance.volume = Float(language.speech.volume)
```

Unknown codes fall back to the code itself as the locale, as `getSpeechConfig`
does today.

Do not create the speech file in this phase; add it with its first caller.

## 5. Content font

`contentFontFamily` stays a string in Core. Turning it into a `Font` belongs
in `DesignSystem/Theme/Typography.swift`:

```swift
/// Content font for a learning language. Interface text never uses this;
/// only words, sentences and their readings.
static func content(_ language: LearningLanguage, size: CGFloat, weight: Font.Weight = .regular) -> Font {
    guard let family = language.contentFontFamily else { return .system(size: size, weight: weight) }
    return .custom(family, size: size).weight(weight)
}
```

Do not create this file in this phase either; add it with the first view that
renders learning content.

## 6. Server changes

These changes happen during [plan 04 §2](04-supabase-migration.md#2-keep-only-backend-dependencies).
They remove the server's language-config dependency before the Swift work;
do not copy `shared/config/` into the functions or repeat these edits later.

1. `generate-text/workflows/card-title.ts`: use the existing request's
   `nativeWritingSystem` as the language/writing-system description instead
   of `getLearningLang(code).name`. It already includes the language name
   (§1); do not parse it or add a required request field. Keep language-specific
   prompt guidance keyed by code, with `languageNotes` keyed on plain strings.
2. Colocate card-title input/output schemas, tones, and inferred types in that
   workflow. Replace the language-config import with the explicit supported
   code list beside the input schema: `ja`, `zh-Hant`, `ko`, `pl`, `uk`.
   Keep HTTP envelope schemas in `generate-text/index.ts`, with no workflow
   importing that entrypoint. No separate text-generation contracts file is
   needed.

The supported-code list is then written in two places, Swift and the request
contract. That duplication is accepted and has one rule: **adding a language
edits both.** The alternative — accepting any string and letting the client be
the sole authority — removes the duplication but stops rejecting nonsense
codes at the edge; keep the explicit list.

Supported codes without specific prompt guidance simply receive no extra
notes. Unsupported codes remain rejected by the request schema. The Swift
language catalog and server prompt guidance have separate owners; fonts,
emoji, writing-display helpers, and on-device speech settings stay client-side.

## 7. The remaining old configuration files

| Old file | Disposition |
| --- | --- |
| `shared/config/languages.ts` | Port client data by this plan; remove the server dependency during plan 04. Do not copy the TypeScript table. |
| `shared/config/writing-display-mode.ts` | Port client rules by this plan, §3. Do not copy into the backend. |
| `shared/contracts/database.ts` | Swift models and enum contracts already ported per plan 03. Plan 04 retains only backend-used contracts in `_shared/contracts/database.ts`. |
| `shared/contracts/user-settings.ts` | Do not copy into the backend. Enums already in `UserSettings.swift`; defaults already inline in `AppDatabase.createInitialRecordsIfNeeded`, one call site, leave them. The zod `.catch(default)` leniency gets no Swift equivalent — validate at the import boundary, per plan 03. |
| `shared/contracts/text-generation.ts` | Colocate backend schemas in `generate-text/index.ts` and its card-title workflow per §6. Client payload structs live in `Features/AddCard/Data/CardTitleGeneration.swift` when Add card lands. |
| `src/i18n/config.ts`, `src/i18n/locales/**`, `src/i18n/plural.ts` | Dies. The interface language is the system's on iOS: the supported list becomes the project's localizations, strings move to `Resources/Localizable.xcstrings`, plurals become xcstrings plural variations. The `en` and `uk` strings themselves are worth carrying over. |
| `src/theme/**` | Already recorded verbatim in `docs/design.md`; becomes `DesignSystem/Theme/`. |
| `app.json` | Dies. The parts that mattered are Xcode build settings — see `docs/ios-configuration.md`. |
| `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY` | [Plan 07](07-supabase-ios-integration.md): `Config/AppConfiguration.swift` plus an xcconfig pair. |
| `drizzle.config.ts` | Dies; `DatabaseMigrator` replaces it. |
| `babel.config.js`, `metro.config.js`, `eslint.config.js`, `tsconfig.json`, `package.json` | Die with the React Native app. |
| `server/supabase/config.toml` | Moves as is; it configures the Supabase CLI, not the app. |
| Deployment/tunnel `scripts/supabase-*.sh` | Move the three scripts to `tools/supabase/` per plan 04. Backup tooling is deferred. |

## 8. Verification

- Build the app after adding the file.
- Check the derived modes against the source behaviour: Japanese offers all
  four, Korean drops the two phonetic modes, Polish offers only
  `standardOnly`, and the full mode normalizes to `standardAndTransliterated`
  for Korean and to `standardOnly` for Polish.
- Confirm `LearningLanguage.with(code:)` returns `nil` for an unsupported code
  rather than a default language.
- When speech is wired, confirm the rate conversion by ear against the old
  app; the failure is subtle and sounds like a voice that is merely fast.
- During plan 04's server verification, confirm card-title requests retain
  Japanese guidance, supported codes without special guidance work without
  extra notes, and unsupported codes are still rejected.
- Do not add tests without approval. Do not commit or push without approval.

## 9. Out of scope

The settings screens that consume this configuration, cloud text-to-speech
wiring, localization of user-facing language labels, and adding any language
beyond the five listed.

import Foundation

/// A language the app can teach. Configuration, not a column type: rows store
/// `lang` as a plain string.
nonisolated struct LearningLanguage: Identifiable, Equatable, Sendable {
    /// Identifies the language or writing system inside the app.
    let code: String
    /// The regional variant used for learning content and pronunciation.
    /// Dates and numbers use the user's runtime locale instead.
    let contentLocale: String
    /// English language description for generation prompts, not a UI label.
    let promptName: String
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
    /// The phonetic layer is this language's spoken reading of an isolated
    /// word, not a display aid. Sentences still speak their standard writing.
    var speaksPhoneticWords = false
}

/// What the device synthesizer reads with. Distinct from `CloudVoice`, which
/// selects the generation provider's voice; neither derives from the other.
nonisolated struct SpokenVoice: Equatable, Sendable {
    /// BCP-47 locale handed to the synthesizer, e.g. `ja-JP`.
    var locale: String
    var settings: SpeechSettings
}

nonisolated struct CloudVoice: Equatable, Sendable {
    /// Key in the audio function's voice map.
    let name: String
    /// The provider's code for the language.
    let languageCode: String
}

nonisolated extension LearningLanguage {
    static let all = [japanese, mandarinTraditional, korean, polish, ukrainian]

    static func with(code: String) -> LearningLanguage? {
        all.first { $0.code == code }
    }

    static let japanese = LearningLanguage(
        code: "ja", contentLocale: "ja-JP",
        promptName: "Japanese", nativeName: "日本語", emoji: "🇯🇵",
        writing: WritingVariants(standard: "Kanji and kana", phonetic: "Hiragana", transliterated: "Romaji"),
        speech: SpeechSettings(speaksPhoneticWords: true),
        contentFontFamily: "Hiragino Sans",
        cloudVoice: CloudVoice(name: "japanese_female_fumi", languageCode: "ja")
    )

    static let mandarinTraditional = LearningLanguage(
        code: "zh-Hant", contentLocale: "zh-TW",
        promptName: "Mandarin (Traditional)", nativeName: "繁體中文", emoji: "🇹🇼",
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
        promptName: "Korean", nativeName: "한국어", emoji: "🇰🇷",
        writing: WritingVariants(standard: "Hangul", transliterated: "Revised Romanization of Korean"),
        speech: SpeechSettings(),
        contentFontFamily: nil,
        cloudVoice: nil
    )

    static let polish = LearningLanguage(
        code: "pl", contentLocale: "pl-PL",
        promptName: "Polish", nativeName: "Polski", emoji: "🇵🇱",
        writing: WritingVariants(standard: "Polish Latin alphabet"),
        speech: SpeechSettings(),
        contentFontFamily: nil,
        cloudVoice: nil
    )

    static let ukrainian = LearningLanguage(
        code: "uk", contentLocale: "uk-UA",
        promptName: "Ukrainian", nativeName: "Українська", emoji: "🇺🇦",
        writing: WritingVariants(standard: "Ukrainian Cyrillic", phonetic: "Pronunciation", transliterated: "Romanization"),
        speech: SpeechSettings(),
        contentFontFamily: nil,
        cloudVoice: nil
    )
}

nonisolated extension LearningLanguage {
    /// Device speech for this language's content.
    var deviceSpeech: SpokenVoice { SpokenVoice(locale: contentLocale, settings: speech) }

    /// What the synthesizer reads for an isolated word. Japanese reads kana:
    /// a kanji spelling on its own has several possible readings and no
    /// context to choose between them. Sentences keep their standard writing,
    /// which the synthesizer needs to parse the grammar. Zhuyin and
    /// romanizations are display layers and are never spoken. Independent of
    /// the user's writing display mode; audio generation uses the same text.
    func spokenWord(_ standard: String, phonetic: String?) -> String {
        guard speech.speaksPhoneticWords, let phonetic, !phonetic.isEmpty else { return standard }
        return phonetic
    }
}

/// A language the app's content is translated into.
nonisolated struct NativeLanguage: Identifiable, Equatable, Sendable {
    let code: String
    let name: String
    let nativeName: String
    let emoji: String
    /// BCP-47 locale for device speech of translations.
    let voiceLocale: String
    /// Read at full speed: this is the language the learner already knows.
    var speech = SpeechSettings(rate: 1)

    var id: String { code }
    var deviceSpeech: SpokenVoice { SpokenVoice(locale: voiceLocale, settings: speech) }

    static let all = [english]
    static let english = NativeLanguage(
        code: "en", name: "English", nativeName: "English", emoji: "🇬🇧", voiceLocale: "en-US"
    )
}

// MARK: - Writing display modes

/// One of the written forms a language can show alongside its standard script.
nonisolated enum WritingLayer: Sendable {
    case standard, phonetic, transliterated
}

nonisolated extension WritingDisplayMode {
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

nonisolated extension LearningLanguage {
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

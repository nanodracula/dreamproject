import Foundation

/// A sentence, phrase, or question in a learning language, with one selected
/// translation, a word-by-word breakdown, and embedded media metadata.
nonisolated struct Sentence: Codable, Equatable, Sendable {
    var id: UUID
    var lang: String
    var title: String
    var sentenceType: SentenceType
    var source: String?
    var writingTransliterated: String
    var writingPhonetic: String?
    var difficultyLevel: Int?
    /// The translation for the user's selected native language.
    var translations: String
    var breakdown = SentenceBreakdown()
    var tags: [String] = []
    var photo = ContentPhoto()
    var audio = ContentAudio()
    var favoritedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

/// The kind of a sentence row.
nonisolated enum SentenceType: String, Codable, Sendable, CaseIterable {
    case phrase
    case sentence
    case question
}

/// A word-by-word explanation of a sentence, stored as JSON inside the
/// `breakdown` column.
nonisolated struct SentenceBreakdown: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion = SentenceBreakdown.currentSchemaVersion
    var items: [SentenceBreakdownItem] = []
}

/// One chunk of a sentence breakdown, discriminated by the flat `type` key.
nonisolated enum SentenceBreakdownItem: Codable, Equatable, Sendable {
    case word(SentenceBreakdownWord)
    case punctuation(SentenceBreakdownPunctuation)

    private enum CodingKeys: String, CodingKey {
        case type
        case partOfSpeech
    }

    private enum Kind: String, Codable {
        case word
        case punctuation
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .word:
            self = .word(try SentenceBreakdownWord(from: decoder))
        case .punctuation:
            self = .punctuation(try SentenceBreakdownPunctuation(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .word(let word):
            try container.encode(Kind.word, forKey: .type)
            try word.encode(to: encoder)
        case .punctuation(let punctuation):
            try container.encode(Kind.punctuation, forKey: .type)
            try container.encode(PartOfSpeech.punctuation, forKey: .partOfSpeech)
            try punctuation.encode(to: encoder)
        }
    }
}

/// A word chunk of a sentence breakdown.
nonisolated struct SentenceBreakdownWord: Codable, Equatable, Sendable {
    /// Any value except `.punctuation`; enforced at the import boundary.
    var partOfSpeech: PartOfSpeech
    var originalChunk: String
    var baseForm: String
    var frequencyRank: FrequencyRank?
    var details: String
    var translationInContext: String
    var otherTranslations: [String] = []
    var writingPhonetic: String?
    var writingTransliterated: String
}

/// A punctuation chunk of a sentence breakdown. Its part of speech is always
/// `PUNCT` and is written by the enclosing item's encoder.
nonisolated struct SentenceBreakdownPunctuation: Codable, Equatable, Sendable {
    var originalChunk: String
    var details: String
}

import Foundation

/// A vocabulary word in a learning language, with one selected translation
/// and embedded media metadata.
nonisolated struct Word: Codable, Equatable, Sendable {
    var id: UUID
    var lang: String
    var title: String
    var definition: String
    var baseForm: String?
    var partOfSpeech: PartOfSpeech
    var writingTransliterated: String
    var writingPhonetic: String?
    var difficultyLevel: Int?
    var frequencyRank: FrequencyRank?
    /// The translation for the user's selected native language.
    var translations: String
    var tags: [String]
    /// Ordered example sentence IDs. Not a SQL foreign key.
    var sentenceIds: [UUID]
    var photo: ContentPhoto
    var audio: ContentAudio
    var favoritedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: UUID,
        lang: String,
        title: String,
        definition: String,
        baseForm: String? = nil,
        partOfSpeech: PartOfSpeech,
        writingTransliterated: String,
        writingPhonetic: String? = nil,
        difficultyLevel: Int? = nil,
        frequencyRank: FrequencyRank? = nil,
        translations: String,
        tags: [String] = [],
        sentenceIds: [UUID] = [],
        photo: ContentPhoto = ContentPhoto(),
        audio: ContentAudio = ContentAudio(),
        favoritedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.lang = lang
        self.title = title
        self.definition = definition
        self.baseForm = baseForm
        self.partOfSpeech = partOfSpeech
        self.writingTransliterated = writingTransliterated
        self.writingPhonetic = writingPhonetic
        self.difficultyLevel = difficultyLevel
        self.frequencyRank = frequencyRank
        self.translations = translations
        self.tags = tags
        self.sentenceIds = sentenceIds
        self.photo = photo
        self.audio = audio
        self.favoritedAt = favoritedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

/// Universal part-of-speech tags shared by words and sentence breakdowns.
nonisolated enum PartOfSpeech: String, Codable, Sendable, CaseIterable {
    case adjective = "ADJ"
    case adposition = "ADP"
    case adverb = "ADV"
    case auxiliary = "AUX"
    case coordinatingConjunction = "CCONJ"
    case determiner = "DET"
    case interjection = "INTJ"
    case noun = "NOUN"
    case numeral = "NUM"
    case particle = "PART"
    case pronoun = "PRON"
    case properNoun = "PROPN"
    case punctuation = "PUNCT"
    case subordinatingConjunction = "SCONJ"
    case symbol = "SYM"
    case verb = "VERB"
    case other = "X"
}

/// Word frequency buckets. The raw value is the bucket's upper bound.
nonisolated enum FrequencyRank: Int, Codable, Sendable, CaseIterable {
    case top100 = 100
    case top200 = 200
    case top500 = 500
    case top1000 = 1000
    case top2000 = 2000
    case top5000 = 5000
    case top10000 = 10000
    case top20000 = 20000
}

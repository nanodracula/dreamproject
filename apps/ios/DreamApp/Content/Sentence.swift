import Foundation
import GRDB

/// A sentence, phrase, or question in a learning language, with one selected
/// translation, a word-by-word breakdown, and embedded media metadata.
nonisolated struct Sentence: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "sentences"

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
    var breakdown: SentenceBreakdown
    var tags: [String]
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
        sentenceType: SentenceType,
        source: String? = nil,
        writingTransliterated: String,
        writingPhonetic: String? = nil,
        difficultyLevel: Int? = nil,
        translations: String,
        breakdown: SentenceBreakdown = SentenceBreakdown(),
        tags: [String] = [],
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
        self.sentenceType = sentenceType
        self.source = source
        self.writingTransliterated = writingTransliterated
        self.writingPhonetic = writingPhonetic
        self.difficultyLevel = difficultyLevel
        self.translations = translations
        self.breakdown = breakdown
        self.tags = tags
        self.photo = photo
        self.audio = audio
        self.favoritedAt = favoritedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case lang
        case title
        case sentenceType = "sentence_type"
        case source
        case writingTransliterated = "writing_transliterated"
        case writingPhonetic = "writing_phonetic"
        case difficultyLevel = "difficulty_level"
        case translations
        case breakdown
        case tags
        case photo
        case audio
        case favoritedAt = "favorited_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let lang = Column(CodingKeys.lang)
        static let title = Column(CodingKeys.title)
        static let sentenceType = Column(CodingKeys.sentenceType)
        static let source = Column(CodingKeys.source)
        static let writingTransliterated = Column(CodingKeys.writingTransliterated)
        static let writingPhonetic = Column(CodingKeys.writingPhonetic)
        static let difficultyLevel = Column(CodingKeys.difficultyLevel)
        static let translations = Column(CodingKeys.translations)
        static let breakdown = Column(CodingKeys.breakdown)
        static let tags = Column(CodingKeys.tags)
        static let photo = Column(CodingKeys.photo)
        static let audio = Column(CodingKeys.audio)
        static let favoritedAt = Column(CodingKeys.favoritedAt)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
        static let deletedAt = Column(CodingKeys.deletedAt)
    }
}

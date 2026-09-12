import Foundation
import GRDB

/// A vocabulary word in a learning language, with one selected translation
/// and embedded media metadata.
nonisolated struct Word: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "words"

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

    enum CodingKeys: String, CodingKey {
        case id
        case lang
        case title
        case definition
        case baseForm = "base_form"
        case partOfSpeech = "part_of_speech"
        case writingTransliterated = "writing_transliterated"
        case writingPhonetic = "writing_phonetic"
        case difficultyLevel = "difficulty_level"
        case frequencyRank = "frequency_rank"
        case translations
        case tags
        case sentenceIds = "sentence_ids"
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
        static let definition = Column(CodingKeys.definition)
        static let baseForm = Column(CodingKeys.baseForm)
        static let partOfSpeech = Column(CodingKeys.partOfSpeech)
        static let writingTransliterated = Column(CodingKeys.writingTransliterated)
        static let writingPhonetic = Column(CodingKeys.writingPhonetic)
        static let difficultyLevel = Column(CodingKeys.difficultyLevel)
        static let frequencyRank = Column(CodingKeys.frequencyRank)
        static let translations = Column(CodingKeys.translations)
        static let tags = Column(CodingKeys.tags)
        static let sentenceIds = Column(CodingKeys.sentenceIds)
        static let photo = Column(CodingKeys.photo)
        static let audio = Column(CodingKeys.audio)
        static let favoritedAt = Column(CodingKeys.favoritedAt)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
        static let deletedAt = Column(CodingKeys.deletedAt)
    }
}

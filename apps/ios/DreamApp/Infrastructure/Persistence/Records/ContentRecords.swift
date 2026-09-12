import GRDB

nonisolated extension Word: FetchableRecord, PersistableRecord {
    static let databaseTableName = "words"
    static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
    static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .convertToSnakeCase

    enum Columns {
        static let id = Column("id")
        static let lang = Column("lang")
        static let title = Column("title")
        static let definition = Column("definition")
        static let baseForm = Column("base_form")
        static let partOfSpeech = Column("part_of_speech")
        static let writingTransliterated = Column("writing_transliterated")
        static let writingPhonetic = Column("writing_phonetic")
        static let difficultyLevel = Column("difficulty_level")
        static let frequencyRank = Column("frequency_rank")
        static let translations = Column("translations")
        static let tags = Column("tags")
        static let sentenceIds = Column("sentence_ids")
        static let photo = Column("photo")
        static let audio = Column("audio")
        static let favoritedAt = Column("favorited_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
        static let deletedAt = Column("deleted_at")
    }

    /// Live rows in a language.
    static func active(lang: String) -> QueryInterfaceRequest<Word> {
        filter(Columns.lang == lang && Columns.deletedAt == nil)
    }
}

nonisolated extension Sentence: FetchableRecord, PersistableRecord {
    static let databaseTableName = "sentences"
    static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
    static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .convertToSnakeCase

    enum Columns {
        static let id = Column("id")
        static let lang = Column("lang")
        static let title = Column("title")
        static let sentenceType = Column("sentence_type")
        static let source = Column("source")
        static let writingTransliterated = Column("writing_transliterated")
        static let writingPhonetic = Column("writing_phonetic")
        static let difficultyLevel = Column("difficulty_level")
        static let translations = Column("translations")
        static let breakdown = Column("breakdown")
        static let tags = Column("tags")
        static let photo = Column("photo")
        static let audio = Column("audio")
        static let favoritedAt = Column("favorited_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
        static let deletedAt = Column("deleted_at")
    }

    /// Live rows in a language.
    static func active(lang: String) -> QueryInterfaceRequest<Sentence> {
        filter(Columns.lang == lang && Columns.deletedAt == nil)
    }
}

nonisolated extension PartOfSpeech: DatabaseValueConvertible {}
nonisolated extension SentenceType: DatabaseValueConvertible {}
nonisolated extension FrequencyRank: DatabaseValueConvertible {}

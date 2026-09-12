import GRDB

nonisolated extension Word: FetchableRecord, PersistableRecord {
    static let databaseTableName = "words"
    static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
    static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .convertToSnakeCase

    enum Columns: String, ColumnExpression {
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

    /// Live rows in a language.
    static func active(lang: String) -> QueryInterfaceRequest<Word> {
        filter(Columns.lang == lang && Columns.deletedAt == nil)
    }
}

nonisolated extension Sentence: FetchableRecord, PersistableRecord {
    static let databaseTableName = "sentences"
    static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
    static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .convertToSnakeCase

    enum Columns: String, ColumnExpression {
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

    /// Live rows in a language.
    static func active(lang: String) -> QueryInterfaceRequest<Sentence> {
        filter(Columns.lang == lang && Columns.deletedAt == nil)
    }
}

nonisolated extension PartOfSpeech: DatabaseValueConvertible {}
nonisolated extension SentenceType: DatabaseValueConvertible {}
nonisolated extension FrequencyRank: DatabaseValueConvertible {}

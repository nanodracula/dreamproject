import GRDB

nonisolated extension UserSettings: FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_settings"
    static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
    static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .convertToSnakeCase

    enum Columns: String, ColumnExpression {
        case userId = "user_id"
        case nativeLanguage = "native_language"
        case activeLearningLanguage = "active_learning_language"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

nonisolated extension UserLearningLanguageSettings: FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_learning_languages_settings"
    static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
    static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .convertToSnakeCase

    enum Columns: String, ColumnExpression {
        case id
        case userId = "user_id"
        case languageCode = "language_code"
        case knowledgeLevel = "knowledge_level"
        case writingDisplayMode = "writing_display_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

nonisolated extension KnowledgeLevel: DatabaseValueConvertible {}
nonisolated extension WritingDisplayMode: DatabaseValueConvertible {
    /// Unknown strings read as `.standardOnly`, matching `Codable` decoding.
    /// Nothing is written back; malformed types still fail.
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let rawValue = String.fromDatabaseValue(dbValue) else { return nil }
        return Self(rawValue: rawValue) ?? .standardOnly
    }
}

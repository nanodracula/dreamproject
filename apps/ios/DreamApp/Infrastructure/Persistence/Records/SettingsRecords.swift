import GRDB

nonisolated extension UserSettings: FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_settings"
    static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
    static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .convertToSnakeCase

    enum Columns {
        static let userId = Column("user_id")
        static let nativeLanguage = Column("native_language")
        static let activeLearningLanguage = Column("active_learning_language")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
        static let deletedAt = Column("deleted_at")
    }
}

nonisolated extension UserLearningLanguageSettings: FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_learning_languages_settings"
    static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
    static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .convertToSnakeCase

    enum Columns {
        static let id = Column("id")
        static let userId = Column("user_id")
        static let languageCode = Column("language_code")
        static let knowledgeLevel = Column("knowledge_level")
        static let writingDisplayMode = Column("writing_display_mode")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
        static let deletedAt = Column("deleted_at")
    }
}

nonisolated extension KnowledgeLevel: DatabaseValueConvertible {}
nonisolated extension WritingDisplayMode: DatabaseValueConvertible {}

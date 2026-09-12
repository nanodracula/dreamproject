import Foundation
import GRDB

/// The learner's self-assessed level in an enrolled language.
nonisolated enum KnowledgeLevel: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case beginner
    case intermediate
    case advanced
}

/// How written text is displayed for an enrolled language.
nonisolated enum WritingDisplayMode: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case standardOnly
    case standardAndPhonetic
    case standardAndTransliterated
    case standardAndPhoneticAndTransliterated
}

/// An enrolled learning language and its settings. One row per
/// `(user_id, language_code)` pair.
nonisolated struct UserLearningLanguageSettings: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_learning_languages_settings"

    var id: UUID
    var userId: UUID
    var languageCode: String
    var knowledgeLevel: KnowledgeLevel
    var writingDisplayMode: WritingDisplayMode
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case languageCode = "language_code"
        case knowledgeLevel = "knowledge_level"
        case writingDisplayMode = "writing_display_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let userId = Column(CodingKeys.userId)
        static let languageCode = Column(CodingKeys.languageCode)
        static let knowledgeLevel = Column(CodingKeys.knowledgeLevel)
        static let writingDisplayMode = Column(CodingKeys.writingDisplayMode)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
        static let deletedAt = Column(CodingKeys.deletedAt)
    }
}

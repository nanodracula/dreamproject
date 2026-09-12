import Foundation
import GRDB

/// Account-level settings. One row per user.
nonisolated struct UserSettings: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_settings"

    var userId: UUID
    var nativeLanguage: String
    var activeLearningLanguage: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nativeLanguage = "native_language"
        case activeLearningLanguage = "active_learning_language"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    enum Columns {
        static let userId = Column(CodingKeys.userId)
        static let nativeLanguage = Column(CodingKeys.nativeLanguage)
        static let activeLearningLanguage = Column(CodingKeys.activeLearningLanguage)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
        static let deletedAt = Column(CodingKeys.deletedAt)
    }
}

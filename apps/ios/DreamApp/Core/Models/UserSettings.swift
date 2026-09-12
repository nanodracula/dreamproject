import Foundation

/// Account-level settings. One row per user.
nonisolated struct UserSettings: Codable, Equatable, Sendable {
    var userId: UUID
    var nativeLanguage: String
    var activeLearningLanguage: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

/// The learner's self-assessed level in an enrolled language.
nonisolated enum KnowledgeLevel: String, Codable, Sendable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}

/// How written text is displayed for an enrolled language.
nonisolated enum WritingDisplayMode: String, Codable, Sendable, CaseIterable {
    case standardOnly
    case standardAndPhonetic
    case standardAndTransliterated
    case standardAndPhoneticAndTransliterated
}

/// An enrolled learning language and its settings. One row per
/// `(user_id, language_code)` pair.
nonisolated struct UserLearningLanguageSettings: Codable, Equatable, Sendable {
    var id: UUID
    var userId: UUID
    var languageCode: String
    var knowledgeLevel: KnowledgeLevel
    var writingDisplayMode: WritingDisplayMode
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

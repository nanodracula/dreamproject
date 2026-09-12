import Foundation
import GRDB

/// The application database.
///
/// Owns the schema migrations and the initial records. The underlying
/// connection is exposed as `any DatabaseWriter` so the app can move from
/// `DatabaseQueue` to `DatabasePool` later, and tests can inject an isolated
/// in-memory `DatabaseQueue`.
nonisolated struct AppDatabase: Sendable {
    /// The open database connection.
    let writer: any DatabaseWriter

    /// The local guest user ID used until authentication is implemented.
    static let guestUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Wraps an open connection, runs pending migrations, and creates the
    /// initial records when they are absent.
    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
        try Self.createInitialRecordsIfNeeded(writer)
    }

    // MARK: - Opening

    /// Opens the persistent app database in Application Support.
    static func openPersistent() throws -> AppDatabase {
        let directory = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "Database", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try openPersistent(at: directory.appending(path: "dreamapp.sqlite"))
    }

    /// Opens (or creates) a file-backed database at the given location.
    static func openPersistent(at fileURL: URL) throws -> AppDatabase {
        try AppDatabase(DatabaseQueue(path: fileURL.path))
    }

    /// Opens an isolated in-memory database.
    static func openInMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    // MARK: - Migrations

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_settings") { db in
            try db.create(table: UserSettings.databaseTableName) { t in
                t.primaryKey("user_id", .blob)
                t.column("native_language", .text).notNull()
                t.column("active_learning_language", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }

            try db.create(table: UserLearningLanguageSettings.databaseTableName) { t in
                t.primaryKey("id", .blob)
                t.column("user_id", .blob).notNull()
                    .references(UserSettings.databaseTableName, onDelete: .cascade, onUpdate: .cascade)
                t.column("language_code", .text).notNull()
                t.column("knowledge_level", .text).notNull()
                t.column("writing_display_mode", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
                t.uniqueKey(["user_id", "language_code"])
            }
        }

        migrator.registerMigration("v2_content") { db in
            try db.create(table: Word.databaseTableName) { t in
                t.primaryKey("id", .blob)
                t.column("lang", .text).notNull()
                t.column("title", .text).notNull()
                t.column("definition", .text).notNull()
                t.column("base_form", .text)
                t.column("part_of_speech", .text).notNull()
                t.column("writing_transliterated", .text).notNull()
                t.column("writing_phonetic", .text)
                t.column("difficulty_level", .integer)
                t.column("frequency_rank", .integer)
                t.column("translations", .text).notNull()
                t.column("tags", .text).notNull()
                t.column("sentence_ids", .text).notNull()
                t.column("photo", .text).notNull()
                t.column("audio", .text).notNull()
                t.column("favorited_at", .datetime)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }

            try db.create(table: Sentence.databaseTableName) { t in
                t.primaryKey("id", .blob)
                t.column("lang", .text).notNull()
                t.column("title", .text).notNull()
                t.column("sentence_type", .text).notNull()
                t.column("source", .text)
                t.column("writing_transliterated", .text).notNull()
                t.column("writing_phonetic", .text)
                t.column("difficulty_level", .integer)
                t.column("translations", .text).notNull()
                t.column("breakdown", .text).notNull()
                t.column("tags", .text).notNull()
                t.column("photo", .text).notNull()
                t.column("audio", .text).notNull()
                t.column("favorited_at", .datetime)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }

            // GRDB's index builder cannot express a DESC column, so use SQL.
            for table in [Word.databaseTableName, Sentence.databaseTableName] {
                try db.execute(sql: """
                    CREATE INDEX "index_\(table)_on_lang_created_at"
                    ON "\(table)"("lang", "created_at" DESC)
                    WHERE "deleted_at" IS NULL
                    """)
            }
        }

        return migrator
    }

    // MARK: - Initial records

    /// Creates the guest settings row and its Japanese enrollment in one
    /// transaction when the guest row is absent. Existing rows are left as is.
    private static func createInitialRecordsIfNeeded(_ writer: any DatabaseWriter) throws {
        try writer.write { db in
            guard try !UserSettings.exists(db, key: guestUserID) else { return }
            let now = Date()
            let settings = UserSettings(
                userId: guestUserID,
                nativeLanguage: "en",
                activeLearningLanguage: "ja",
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
            let enrollment = UserLearningLanguageSettings(
                id: UUID(),
                userId: guestUserID,
                languageCode: settings.activeLearningLanguage,
                knowledgeLevel: .beginner,
                writingDisplayMode: .standardOnly,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
            try settings.insert(db)
            try enrollment.insert(db)
        }
    }
}

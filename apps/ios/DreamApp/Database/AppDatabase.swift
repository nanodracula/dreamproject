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

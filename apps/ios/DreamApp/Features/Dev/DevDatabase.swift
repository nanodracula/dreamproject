import Foundation
import GRDB

/// Developer operations on the local database.
nonisolated struct DevDatabase: Sendable {
    let writer: any DatabaseWriter

    struct Stats: Equatable, Sendable {
        var databaseSizeKb: Double
        var wordCount: Int
        var sentenceCount: Int
    }

    func stats() async throws -> Stats {
        try await writer.read { db in
            let pageCount = try Int.fetchOne(db, sql: "PRAGMA page_count") ?? 0
            let pageSize = try Int.fetchOne(db, sql: "PRAGMA page_size") ?? 0
            return Stats(
                databaseSizeKb: Double(pageCount * pageSize) / 1024,
                wordCount: try Word.fetchCount(db),
                sentenceCount: try Sentence.fetchCount(db)
            )
        }
    }

    /// Replaces all words and sentences with the bundled seed. Settings stay.
    func resetFromSeed() async throws {
        let seed = try ContentSeed.load()
        try await writer.write { db in
            try Word.deleteAll(db)
            try Sentence.deleteAll(db)
            for sentence in seed.sentences { try sentence.insert(db) }
            for word in seed.words { try word.insert(db) }
        }
    }

    /// Times a primary-key lookup of the first word. `nil` when there are none.
    func timeWordLookup() async throws -> Duration? {
        try await writer.read { db in
            guard let id = try Word.select(Word.Columns.id, as: UUID.self).fetchOne(db) else { return nil }
            var found: Word?
            let duration = try ContinuousClock().measure {
                found = try Word.fetchOne(db, key: id)
            }
            return found == nil ? nil : duration
        }
    }
}

/// The bundled content: `words.<lang>.json` and `sentences.<lang>.json` for
/// each language that ships them.
nonisolated struct ContentSeed: Sendable {
    var words: [Word] = []
    var sentences: [Sentence] = []

    static func load(bundle: Bundle = .main) throws -> ContentSeed {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var seed = ContentSeed()
        for language in LearningLanguage.all {
            if let url = bundle.url(forResource: "words.\(language.code)", withExtension: "json") {
                seed.words += try decoder.decode([Word].self, from: Data(contentsOf: url))
            }
            if let url = bundle.url(forResource: "sentences.\(language.code)", withExtension: "json") {
                seed.sentences += try decoder.decode([Sentence].self, from: Data(contentsOf: url))
            }
        }
        return seed
    }
}

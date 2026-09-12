import CryptoKit
import Foundation
import Supabase

nonisolated enum MediaCacheError: Error {
    case invalidStoragePath(String)
    case badResponse(statusCode: Int?)
}

/// Resolves stored media to a local file: an existing download when there is
/// one, otherwise a fetch from the public bucket into `Caches/`. One download
/// per object, shared by every caller. A caller that stops waiting is released
/// at once while the download runs on, so the file is there next time.
/// Prefetching and the `offlineAudio` device setting hook in here.
actor MediaCache {
    private let supabase: SupabaseClient
    private let directory: URL
    private let urlSession: URLSession
    /// Callers waiting on each in-flight download, keyed by storage path.
    /// A key is present exactly while its download runs.
    private var waiters: [String: [UUID: CheckedContinuation<URL, any Error>]] = [:]

    init(supabase: SupabaseClient, directory: URL = .cachesDirectory.appending(path: "media")) {
        self.supabase = supabase
        self.directory = directory
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        urlSession = URLSession(configuration: configuration)
    }

    /// The local file for a `bucket/path` storage path. Throws
    /// `CancellationError` as soon as the caller is cancelled, whether or not
    /// the download has finished.
    func file(for storagePath: String) async throws -> URL {
        let destination = localURL(for: storagePath)
        if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
            return destination
        }
        if waiters[storagePath] == nil {
            waiters[storagePath] = [:]
            // Unstructured on purpose: nobody's cancellation reaches it.
            Task { await download(storagePath, to: destination) }
        }
        let waiterID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters[storagePath, default: [:]][waiterID] = continuation
            }
        } onCancel: {
            Task { await self.cancelWaiter(waiterID, for: storagePath) }
        }
    }

    /// Drops a cached file that turned out unusable, so the next request
    /// downloads it again.
    func invalidate(_ storagePath: String) {
        try? FileManager.default.removeItem(at: localURL(for: storagePath))
    }

    private func localURL(for storagePath: String) -> URL {
        // A digest keeps names unique and short whatever the path contains;
        // the extension is kept so players can sniff the format.
        let digest = SHA256.hash(data: Data(storagePath.utf8)).map { String(format: "%02x", $0) }.joined()
        let fileExtension = URL(filePath: storagePath).pathExtension
        return directory.appending(path: fileExtension.isEmpty ? digest : "\(digest).\(fileExtension)")
    }

    private func cancelWaiter(_ id: UUID, for storagePath: String) {
        waiters[storagePath]?.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    private func download(_ storagePath: String, to destination: URL) async {
        let result: Result<URL, any Error>
        do {
            result = .success(try await fetch(storagePath, to: destination))
        } catch {
            result = .failure(error)
        }
        let pending = waiters.removeValue(forKey: storagePath) ?? [:]
        for continuation in pending.values {
            continuation.resume(with: result)
        }
    }

    private func fetch(_ storagePath: String, to destination: URL) async throws -> URL {
        let parts = storagePath.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { throw MediaCacheError.invalidStoragePath(storagePath) }
        let url = try supabase.storage.from(String(parts[0])).getPublicURL(path: String(parts[1]))
        let (temporary, response) = try await urlSession.download(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        // An error page saved as audio would be served from the cache forever.
        guard let statusCode, (200..<300).contains(statusCode) else {
            try? FileManager.default.removeItem(at: temporary)
            throw MediaCacheError.badResponse(statusCode: statusCode)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }
}

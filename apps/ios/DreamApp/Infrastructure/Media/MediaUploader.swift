import Foundation
import Supabase

/// Which user-generated-content bucket a file belongs in.
nonisolated enum MediaKind: Sendable, CaseIterable {
    case photo
    case audio

    var bucket: String {
        switch self {
        case .photo: "ugc-photos"
        case .audio: "ugc-audio"
        }
    }

    /// The file extension for a MIME type the bucket accepts, or `nil` when
    /// the bucket's `allowed_mime_types` would reject it.
    func fileExtension(for contentType: String) -> String? {
        switch (self, contentType) {
        case (.photo, "image/jpeg"): "jpg"
        case (.photo, "image/png"): "png"
        case (.photo, "image/webp"): "webp"
        case (.photo, "image/avif"): "avif"
        case (.audio, "audio/mpeg"): "mp3"
        case (.audio, "audio/mp4"), (.audio, "audio/x-m4a"): "m4a"
        case (.audio, "audio/wav"): "wav"
        case (.audio, "audio/ogg"): "ogg"
        case (.audio, "audio/webm"): "webm"
        default: nil
        }
    }
}

/// A stored object, identified the way `PhotoAsset` and `AudioAsset` record it.
nonisolated struct UploadedMedia: Equatable, Sendable {
    let bucket: String
    /// `{userID}/{uuid}.{ext}` inside the bucket.
    let path: String

    /// `bucket/path`: the `storagePath` of an asset.
    var storagePath: String { "\(bucket)/\(path)" }
}

nonisolated enum MediaUploadError: Error {
    /// No session could be restored or created. The storage policies need a user.
    case unauthenticated(any Error)
    case invalidFile(String)
    case uploadFailed(any Error)
}

/// Feature contract, so screens and previews can substitute the network.
nonisolated protocol MediaUploading: Sendable {
    func upload(_ data: Data, contentType: String, as kind: MediaKind) async throws(MediaUploadError) -> UploadedMedia
}

/// Uploads user-generated media into the `ugc-*` buckets under the current
/// user's prefix, as the storage policies require. Uses the user's session,
/// never a server key. The buckets are public: anyone with an object URL can
/// download it; the policies only restrict uploads, listing, and deletion.
nonisolated struct MediaUploader: MediaUploading {
    private let supabase: SupabaseClient
    private let session: SupabaseSession

    init(supabase: SupabaseClient, session: SupabaseSession) {
        self.supabase = supabase
        self.session = session
    }

    func upload(_ data: Data, contentType: String, as kind: MediaKind) async throws(MediaUploadError) -> UploadedMedia {
        let contentType = contentType.split(separator: ";", maxSplits: 1)[0]
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !data.isEmpty else {
            throw .invalidFile("Empty file")
        }
        guard let fileExtension = kind.fileExtension(for: contentType) else {
            throw .invalidFile("Unsupported media type: \(contentType)")
        }

        let userID: UUID
        do {
            userID = try await session.userID()
        } catch {
            throw .unauthenticated(error)
        }

        // The policy compares the first path segment with `auth.uid()::text`,
        // which Postgres renders in lowercase; `uuidString` is uppercase.
        let path = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).\(fileExtension)"
        do {
            try await supabase.storage.from(kind.bucket).upload(
                path,
                data: data,
                options: FileOptions(cacheControl: "31536000", contentType: contentType, upsert: false)
            )
        } catch {
            throw .uploadFailed(error)
        }
        return UploadedMedia(bucket: kind.bucket, path: path)
    }
}

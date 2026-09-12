import Foundation

/// An image attached to a word or sentence.
///
/// Stored as JSON inside the `photo` column. Optional properties may be
/// absent or `null` in stored JSON; unknown keys are ignored on decode.
nonisolated struct PhotoAsset: Codable, Equatable, Sendable {
    /// Full `bucket/path/filename.ext` object path. Also the asset identity:
    /// replacing or regenerating media produces a new path.
    var storagePath: String
    var width: Int?
    var height: Int?
    var origin: MediaOrigin
    /// `"provider:model-id"`, or `nil` when not applicable or unknown.
    var aiModel: String?
}

/// A recording attached to a word or sentence.
///
/// Stored as JSON inside the `audio` column. `subtitleTracks` is reserved
/// for a later phase and intentionally not modeled; any stored value for
/// that key is ignored on decode.
nonisolated struct AudioAsset: Codable, Equatable, Sendable {
    /// Full `bucket/path/filename.ext` object path. Also the asset identity.
    var storagePath: String
    /// The spoken language, independent of the voice.
    var lang: String
    /// A stable voice identifier, not a display label.
    var voice: String?
    /// Default for new recordings; still required when decoding stored JSON.
    var pace: AudioPace = .normal
    var durationMs: Int?
    var origin: MediaOrigin
    /// `"provider:model-id"`, or `nil` when not applicable or unknown.
    var aiModel: String?
}

/// The `photo` column: the main image, if any.
nonisolated struct ContentPhoto: Codable, Equatable, Sendable {
    var main: PhotoAsset?
}

/// The `audio` column: the original pronunciation and the recording of the
/// selected translation, if any.
nonisolated struct ContentAudio: Codable, Equatable, Sendable {
    var title: AudioAsset?
    var translation: AudioAsset?
}

/// Where a media asset came from.
nonisolated enum MediaOrigin: String, Codable, Sendable, CaseIterable {
    case ai
    case user
    case curated
}

/// The speaking pace of an audio recording.
nonisolated enum AudioPace: String, Codable, Sendable, CaseIterable {
    case slow
    case normal
    case fast
}

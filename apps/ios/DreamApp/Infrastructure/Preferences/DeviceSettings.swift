import Foundation

/// Device-local preferences backed by `UserDefaults`.
///
/// These belong to the device, not the account: they are not stored in the
/// database and are not part of future account synchronization.
///
/// `UserDefaults` is thread-safe but not declared `Sendable`, hence `@unchecked`.
nonisolated struct DeviceSettings: @unchecked Sendable {
    enum Keys {
        static let autoplayPronunciation = "autoplayPronunciation"
        static let offlineAudio = "offlineAudio"
        static let offlinePhotos = "offlinePhotos"
    }

    private let defaults: UserDefaults

    /// Registers the default values without overwriting saved choices.
    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        defaults.register(defaults: [
            Keys.autoplayPronunciation: false,
            Keys.offlineAudio: false,
            Keys.offlinePhotos: false,
        ])
    }

    var autoplayPronunciation: Bool {
        get { defaults.bool(forKey: Keys.autoplayPronunciation) }
        nonmutating set { defaults.set(newValue, forKey: Keys.autoplayPronunciation) }
    }

    var offlineAudio: Bool {
        get { defaults.bool(forKey: Keys.offlineAudio) }
        nonmutating set { defaults.set(newValue, forKey: Keys.offlineAudio) }
    }

    var offlinePhotos: Bool {
        get { defaults.bool(forKey: Keys.offlinePhotos) }
        nonmutating set { defaults.set(newValue, forKey: Keys.offlinePhotos) }
    }
}

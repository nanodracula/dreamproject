import Foundation
import Testing
@testable import DreamApp

struct DeviceSettingsTests {
    private func withIsolatedDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "DreamAppTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    @Test func defaultsAreFalse() throws {
        try withIsolatedDefaults { defaults in
            let settings = DeviceSettings(userDefaults: defaults)
            #expect(settings.autoplayPronunciation == false)
            #expect(settings.offlineAudio == false)
            #expect(settings.offlinePhotos == false)
        }
    }

    @Test func savedChoicesSurviveRecreatingTheWrapper() throws {
        try withIsolatedDefaults { defaults in
            let settings = DeviceSettings(userDefaults: defaults)
            settings.autoplayPronunciation = true
            settings.offlinePhotos = true

            let reopened = DeviceSettings(userDefaults: defaults)
            #expect(reopened.autoplayPronunciation == true)
            #expect(reopened.offlineAudio == false)
            #expect(reopened.offlinePhotos == true)

            reopened.autoplayPronunciation = false
            #expect(DeviceSettings(userDefaults: defaults).autoplayPronunciation == false)
        }
    }

    @Test func registeringDefaultsDoesNotOverwriteSavedChoices() throws {
        try withIsolatedDefaults { defaults in
            defaults.set(true, forKey: DeviceSettings.Keys.offlineAudio)
            let settings = DeviceSettings(userDefaults: defaults)
            #expect(settings.offlineAudio == true)
        }
    }
}

import Foundation
import Supabase

/// The composition root. Owns the database, shared repositories, and platform
/// services. Features build their own view models and queries from these.
@MainActor @Observable
final class AppDependencies {
    let database: AppDatabase
    let deviceSettings: DeviceSettings
    let settingsRepository: SettingsRepository
    /// Account settings of the current user, injected into the SwiftUI
    /// environment on its own.
    let settings: AppSettingsModel
    /// The shared Supabase client. Feature request clients, such as
    /// `CardTitleGeneration`, are built from it.
    let supabase: SupabaseClient
    let supabaseSession: SupabaseSession
    let mediaUploader: MediaUploader
    let mediaCache: MediaCache
    let pronunciation: Pronunciation

    init(
        database: AppDatabase,
        deviceSettings: DeviceSettings = DeviceSettings(),
        supabase: SupabaseClient = .live()
    ) {
        self.database = database
        self.deviceSettings = deviceSettings
        self.supabase = supabase
        // The guest user until authentication exists.
        settingsRepository = SettingsRepository(writer: database.writer, userID: AppDatabase.guestUserID)
        settings = AppSettingsModel(repository: settingsRepository)
        supabaseSession = SupabaseSession(auth: supabase.auth)
        mediaUploader = MediaUploader(supabase: supabase, session: supabaseSession)
        mediaCache = MediaCache(supabase: supabase)
        pronunciation = Pronunciation(cache: mediaCache)
    }

    /// Opens and migrates the database off the main actor, then wires the
    /// services on the main actor. Construction does not wait for network IO.
    static func live() async throws -> AppDependencies {
        let database = try await Task.detached(priority: .userInitiated) {
            try AppDatabase.openPersistent()
        }.value
        try Task.checkCancellation()
        return AppDependencies(database: database)
    }
}

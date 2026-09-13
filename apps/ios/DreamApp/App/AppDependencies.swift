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
    let settings: SettingsModel
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
        settings = SettingsModel(repository: settingsRepository)
        supabaseSession = SupabaseSession(auth: supabase.auth)
        mediaUploader = MediaUploader(supabase: supabase, session: supabaseSession)
        mediaCache = MediaCache(supabase: supabase)
        pronunciation = Pronunciation(cache: mediaCache)
    }

    /// Opens the persistent database and wires production services.
    static func live() throws -> AppDependencies {
        AppDependencies(database: try AppDatabase.openPersistent())
    }
}

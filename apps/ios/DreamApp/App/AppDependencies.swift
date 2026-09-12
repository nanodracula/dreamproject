import Foundation

/// The composition root. Owns the database, shared repositories, and platform
/// services. Features build their own view models and queries from these.
@MainActor @Observable
final class AppDependencies {
    let database: AppDatabase
    let deviceSettings: DeviceSettings

    init(database: AppDatabase, deviceSettings: DeviceSettings = DeviceSettings()) {
        self.database = database
        self.deviceSettings = deviceSettings
    }

    /// Opens the persistent database and wires production services.
    static func live() throws -> AppDependencies {
        AppDependencies(database: try AppDatabase.openPersistent())
    }
}

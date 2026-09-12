import Foundation

/// Public client configuration, read from Info.plist where the build
/// substitutes the values of the active environment's xcconfig:
/// `Config/Dev.xcconfig` for Debug, `Config/Prod.xcconfig` for Release.
///
/// A missing or empty key is a build mistake, so the accessors crash at first
/// use rather than let the app run against nothing.
nonisolated enum AppConfiguration {
    nonisolated enum Error: Swift.Error {
        case missingKey(String)
        case invalidValue(String)
    }

    static let supabaseURL = URL(string: "https://" + (try! value(for: "SUPABASE_HOST") as String))!
    static let supabaseAnonKey: String = try! value(for: "SUPABASE_ANON_KEY")

    /// Reads a build-substituted Info.plist value.
    static func value<T: LosslessStringConvertible>(for key: String) throws(Error) -> T {
        guard let object = Bundle.main.object(forInfoDictionaryKey: key) else {
            throw .missingKey(key)
        }
        switch object {
        case let value as T:
            return value
        case let string as String:
            guard !string.isEmpty else { throw .missingKey(key) }
            guard let value = T(string) else { throw .invalidValue(key) }
            return value
        default:
            throw .invalidValue(key)
        }
    }
}

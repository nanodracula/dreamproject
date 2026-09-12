import Foundation
import Supabase

nonisolated extension SupabaseClient {
    /// The shared client for the self-hosted instance.
    ///
    /// Defaults are enough: the SDK persists the auth session in the Keychain
    /// and refreshes tokens itself. Requests carry the user's access token
    /// when a session exists and the anon key otherwise, so function calls
    /// work without a session; only storage uploads need the user.
    static func live() -> SupabaseClient {
        SupabaseClient(supabaseURL: AppConfiguration.supabaseURL, supabaseKey: AppConfiguration.supabaseAnonKey)
    }
}

/// Coordinates the anonymous user session.
///
/// Supabase anonymous sign-in creates a real user with a stable UUID and
/// `is_anonymous = true`; that ID owns the user's uploads. There is no
/// separate account system and no recovery if the Keychain entry is lost. A
/// future login can be linked to this user.
///
/// The SDK owns persistence and refresh; this actor only decides when to
/// create a user, and lets concurrent callers share one in-progress attempt.
actor SupabaseSession {
    private let auth: AuthClient
    private var inProgress: Task<Session, any Error>?

    init(auth: AuthClient) {
        self.auth = auth
    }

    /// The persisted session, refreshed when expired, or a new anonymous
    /// user when the SDK reports that none is stored.
    ///
    /// Connectivity and refresh failures propagate and never create a new
    /// identity; the next call retries. Nothing is cached once the attempt
    /// finishes, so a later call goes back through the SDK.
    @discardableResult
    func session() async throws -> Session {
        if let inProgress {
            return try await inProgress.value
        }
        let task = Task { [auth] in
            do {
                return try await auth.session
            } catch AuthError.sessionMissing {
                return try await auth.signInAnonymously()
            }
        }
        inProgress = task
        defer { inProgress = nil }
        return try await task.value
    }

    /// The current user's ID: the owner prefix the storage policies require.
    func userID() async throws -> UUID {
        try await session().user.id
    }
}

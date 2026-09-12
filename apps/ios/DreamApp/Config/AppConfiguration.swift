import Foundation

/// Public client configuration for the self-hosted Supabase instance.
///
/// The anon key is public by design and ships inside the IPA regardless;
/// row-level security protects the data. The service-role key stays in the
/// deployment environment. One instance, so plain constants: wrap them in
/// `#if DEBUG` if a staging stack ever appears.
nonisolated enum AppConfiguration {
    static let supabaseURL = URL(string: "https://dreamproject-supabase-7b2379-187-77-132-199.sslip.io")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODUzMzEzOTAsImV4cCI6MTg5MzQ1NjAwMCwicm9sZSI6ImFub24iLCJpc3MiOiJzdXBhYmFzZSJ9.8SJCmecqiUAOk42K0kgUzbgep_xjxoi9wCsUu9rSVbs"
}

import Foundation
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        guard let url = URL(string: Secrets.supabaseURL), !Secrets.supabaseAnonKey.isEmpty else {
            fatalError("Missing or invalid Supabase configuration in Secrets.plist")
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
    }

    /// The habit tables let Postgres fill user_id from its `default
    /// auth.uid()`. The card tables send it explicitly instead, because
    /// their upserts target a `(user_id, date)` conflict and being explicit
    /// removes any question of whether the default resolves before the
    /// conflict is evaluated.
    /// Deliberately the SDK's async `session` and nothing else.
    ///
    /// An in-memory fallback (reading AuthService's cached session) was tried
    /// and reverted: it let this return an id while the SDK still had no
    /// token to attach to the request, so a clean "you need to be signed in"
    /// became an opaque "new row violates row-level security policy". This
    /// accessor is the same thing that authorises the HTTP call, so if it
    /// can't produce a session the write was never going to succeed — better
    /// to fail here, with an accurate reason.
    func requireUserId() async throws -> UUID {
        try await client.auth.session.user.id
    }

    /// Non-throwing probe for callers that want to defer rather than fail
    /// when there's no session yet.
    func userIdIfSignedIn() async -> UUID? {
        try? await requireUserId()
    }
}

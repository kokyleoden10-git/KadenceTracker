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
}

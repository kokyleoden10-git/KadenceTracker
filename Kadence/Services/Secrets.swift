import Foundation

/// Reads Kadence/Config/Secrets.plist (git-ignored). Copy Secrets.example.plist
/// to Secrets.plist and fill in your Supabase project's URL + anon key.
enum Secrets {
    private static let dict: [String: Any] = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else {
            fatalError("Secrets.plist not found. Copy Kadence/Config/Secrets.example.plist to Secrets.plist and fill in your Supabase project values.")
        }
        return plist
    }()

    static var supabaseURL: String { dict["SUPABASE_URL"] as? String ?? "" }
    static var supabaseAnonKey: String { dict["SUPABASE_ANON_KEY"] as? String ?? "" }
}

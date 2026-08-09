import Foundation

enum ProfileService {
    /// RLS scopes this to the signed-in user automatically — no explicit
    /// user_id filter needed. Returns nil only in the brief window between
    /// sign-in and the `handle_new_user` trigger's insert completing.
    static func fetchCurrent() async throws -> Profile? {
        let rows: [Profile] = try await SupabaseService.shared.client
            .from("profile")
            .select()
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    struct ProfileUpdate: Encodable {
        var nickname: String?
        var currentLocation: String?
        var birthLocation: String?
        var birthdate: String?
        var birthTime: String?

        enum CodingKeys: String, CodingKey {
            case nickname, birthdate
            case currentLocation = "current_location"
            case birthLocation = "birth_location"
            case birthTime = "birth_time"
        }
    }

    static func update(_ userId: UUID, with values: ProfileUpdate) async throws {
        try await SupabaseService.shared.client
            .from("profile")
            .update(values)
            .eq("user_id", value: userId)
            .execute()
    }
}

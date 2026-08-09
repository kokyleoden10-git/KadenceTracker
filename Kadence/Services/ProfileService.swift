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

        /// Swift's auto-synthesized Encodable uses encodeIfPresent for
        /// Optional properties, which *omits the key* when nil rather than
        /// sending null — PostgREST then leaves that column untouched
        /// instead of clearing it. This explicit encoder always sends the
        /// key (null included) so clearing a field in the UI actually
        /// clears it in the database.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(nickname, forKey: .nickname)
            try container.encode(currentLocation, forKey: .currentLocation)
            try container.encode(birthLocation, forKey: .birthLocation)
            try container.encode(birthdate, forKey: .birthdate)
            try container.encode(birthTime, forKey: .birthTime)
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

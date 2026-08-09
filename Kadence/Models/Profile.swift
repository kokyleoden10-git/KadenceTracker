import Foundation

/// birth_time is a bare `time` column in Postgres (no date/timezone) — kept
/// as a String ("HH:mm:ss") rather than Date to avoid timezone-conversion
/// bugs for a value that isn't a moment in time.
struct Profile: Codable, Identifiable {
    var id: UUID { userId }
    let userId: UUID
    var nickname: String?
    var birthdate: Date?
    var birthTime: String?
    var birthLocation: String?
    var currentLocation: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case nickname, birthdate
        case userId = "user_id"
        case birthTime = "birth_time"
        case birthLocation = "birth_location"
        case currentLocation = "current_location"
        case createdAt = "created_at"
    }
}

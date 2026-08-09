import Foundation

/// birthdate/birth_time are bare `date`/`time` columns in Postgres (no
/// timezone, and for birthdate no time-of-day either). Both are kept as
/// plain strings ("YYYY-MM-DD"/"HH:mm:ss") rather than Date — PostgREST
/// returns them without a time/timezone component, which Swift's Date
/// decoder can't parse, and neither value is actually a moment in time
/// anyway (a birthdate isn't tied to a timezone).
struct Profile: Codable, Identifiable {
    var id: UUID { userId }
    let userId: UUID
    var nickname: String?
    var birthdate: String?
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

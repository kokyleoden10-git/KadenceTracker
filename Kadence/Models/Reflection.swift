import Foundation

struct Reflection: Codable, Identifiable {
    let id: UUID
    var weekStart: Date
    var wentWell: String?
    var whatBroke: String?
    var patternNoticed: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case weekStart = "week_start"
        case wentWell = "went_well"
        case whatBroke = "what_broke"
        case patternNoticed = "pattern_noticed"
        case createdAt = "created_at"
    }
}

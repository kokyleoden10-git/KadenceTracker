import Foundation

enum Domain: String, Codable, CaseIterable {
    case wellbeing, knowledge, creativity, systems
}

enum Tier: String, Codable {
    case anchor, practice
}

enum Direction: String, Codable {
    case build, reduce
}

struct Habit: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var name: String
    var domain: Domain
    var tier: Tier
    var direction: Direction
    var daysActive: [Int]
    var identityStatement: String?
    var stackCue: String?
    var streakCount: Int
    var createdAt: Date
    var archivedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, domain, tier, direction
        case userId = "user_id"
        case daysActive = "days_active"
        case identityStatement = "identity_statement"
        case stackCue = "stack_cue"
        case streakCount = "streak_count"
        case createdAt = "created_at"
        case archivedAt = "archived_at"
    }
}

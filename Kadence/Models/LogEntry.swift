import Foundation

enum PrivacyTier: String, Codable {
    case normal, sensitive
}

/// `doneValue` is 0/1 for boolean-style habits, or 1-5 for habits configured
/// with a scale. The parent Habit determines which interpretation applies.
struct LogEntry: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var habitId: UUID
    var date: Date
    var doneValue: Int
    var note: String?
    var tags: [String]
    var breakContext: String?
    var createdAt: Date
    var privacyTier: PrivacyTier

    var isDone: Bool { doneValue > 0 }

    enum CodingKeys: String, CodingKey {
        case id, date, note, tags
        case userId = "user_id"
        case habitId = "habit_id"
        case doneValue = "done_value"
        case breakContext = "break_context"
        case createdAt = "created_at"
        case privacyTier = "privacy_tier"
    }
}

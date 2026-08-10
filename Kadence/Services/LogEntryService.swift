import Foundation

enum LogEntryService {
    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    /// Spec's days_active uses 0=Sun..6=Sat. Foundation's .weekday component
    /// is 1=Sunday...7=Saturday regardless of locale, so weekday - 1 lines
    /// up directly with no remapping.
    static func todayWeekdayIndex(_ date: Date = Date()) -> Int {
        Calendar.current.component(.weekday, from: date) - 1
    }

    static func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    static func fetchForDate(_ date: Date = Date()) async throws -> [LogEntry] {
        try await SupabaseService.shared.client
            .from("log_entry")
            .select()
            .eq("date", value: dateFormatter.string(from: date))
            .execute()
            .value
    }

    /// All history. Tides folds every cycle onto one lunar axis, so it wants
    /// everything rather than a window — a single user's log is a few
    /// thousand rows a year, which is well within a single request.
    static func fetchAll() async throws -> [LogEntry] {
        try await SupabaseService.shared.client
            .from("log_entry")
            .select()
            .order("date")
            .execute()
            .value
    }

    struct LogEntryInput: Encodable {
        var habitId: UUID
        var date: String
        var doneValue: Int
        var note: String?
        var tags: [String]
        var breakContext: String?
        var privacyTier: PrivacyTier

        enum CodingKeys: String, CodingKey {
            case date, tags, note
            case habitId = "habit_id"
            case doneValue = "done_value"
            case breakContext = "break_context"
            case privacyTier = "privacy_tier"
        }

        /// Same explicit-encode pattern as ProfileUpdate/HabitInput — an
        /// upsert's merge-duplicates resolution treats an omitted key like
        /// a partial update (keeps the old value), so clearing a note or
        /// break_context needs an explicit null, not an omitted key.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(habitId, forKey: .habitId)
            try container.encode(date, forKey: .date)
            try container.encode(doneValue, forKey: .doneValue)
            try container.encode(note, forKey: .note)
            try container.encode(tags, forKey: .tags)
            try container.encode(breakContext, forKey: .breakContext)
            try container.encode(privacyTier, forKey: .privacyTier)
        }
    }

    /// Relies on the (habit_id, date) unique constraint — tapping the same
    /// habit again today updates today's row instead of creating a second
    /// one.
    static func upsert(_ input: LogEntryInput) async throws {
        try await SupabaseService.shared.client
            .from("log_entry")
            .upsert(input, onConflict: "habit_id,date")
            .execute()
    }

    /// Returns a habit to "not yet logged" (distinct from explicitly
    /// marking it not-done) by removing today's row entirely.
    static func clear(habitId: UUID, date: Date = Date()) async throws {
        try await SupabaseService.shared.client
            .from("log_entry")
            .delete()
            .eq("habit_id", value: habitId)
            .eq("date", value: dateFormatter.string(from: date))
            .execute()
    }
}

import Foundation

enum HabitService {
    static func fetchActive() async throws -> [Habit] {
        try await SupabaseService.shared.client
            .from("habit")
            .select()
            .is("archived_at", value: nil)
            .order("created_at")
            .execute()
            .value
    }

    static func fetchArchived() async throws -> [Habit] {
        try await SupabaseService.shared.client
            .from("habit")
            .select()
            .not("archived_at", operator: .is, value: "null")
            .order("archived_at", ascending: false)
            .execute()
            .value
    }

    struct HabitInput: Encodable {
        var name: String
        var domain: Domain
        var tier: Tier
        var direction: Direction
        var daysActive: [Int]
        var identityStatement: String?
        var stackCue: String?

        enum CodingKeys: String, CodingKey {
            case name, domain, tier, direction
            case daysActive = "days_active"
            case identityStatement = "identity_statement"
            case stackCue = "stack_cue"
        }

        /// Same lesson as ProfileUpdate: the synthesized encoder omits nil
        /// Optional fields instead of sending null, which would leave a
        /// cleared identity_statement/stack_cue untouched in the database
        /// on edit. Explicit encode forces the key (and null) through.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(domain, forKey: .domain)
            try container.encode(tier, forKey: .tier)
            try container.encode(direction, forKey: .direction)
            try container.encode(daysActive, forKey: .daysActive)
            try container.encode(identityStatement, forKey: .identityStatement)
            try container.encode(stackCue, forKey: .stackCue)
        }
    }

    static func create(_ input: HabitInput) async throws {
        try await SupabaseService.shared.client
            .from("habit")
            .insert(input)
            .execute()
    }

    static func update(_ id: UUID, with input: HabitInput) async throws {
        try await SupabaseService.shared.client
            .from("habit")
            .update(input)
            .eq("id", value: id)
            .execute()
    }

    /// Soft delete — reversible in spirit (data's still there, just
    /// hidden from fetchActive), matching spec §5's "never hard-delete"
    /// default.
    static func archive(_ id: UUID) async throws {
        struct ArchivePatch: Encodable {
            let archivedAt: Date
            enum CodingKeys: String, CodingKey { case archivedAt = "archived_at" }
        }
        try await SupabaseService.shared.client
            .from("habit")
            .update(ArchivePatch(archivedAt: Date()))
            .eq("id", value: id)
            .execute()
    }

    /// Reverses `archive`. Same encodeIfPresent trap as ProfileUpdate/
    /// HabitInput applies here — a plain `Encodable` with `archivedAt: nil`
    /// would omit the key and leave the habit archived, so this encodes
    /// explicitly.
    static func unarchive(_ id: UUID) async throws {
        struct UnarchivePatch: Encodable {
            enum CodingKeys: String, CodingKey { case archivedAt = "archived_at" }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeNil(forKey: .archivedAt)
            }
        }
        try await SupabaseService.shared.client
            .from("habit")
            .update(UnarchivePatch())
            .eq("id", value: id)
            .execute()
    }

    /// Real hard delete — an explicit exception to spec §5's "never
    /// hard-delete" default, added on request. log_entry.habit_id has
    /// `on delete cascade`, so this also permanently destroys every logged
    /// entry for this habit, not just the habit definition. The confirming
    /// UI must say so, not just "can't be undone."
    static func delete(_ id: UUID) async throws {
        try await SupabaseService.shared.client
            .from("habit")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

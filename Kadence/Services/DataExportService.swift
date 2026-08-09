import Foundation

/// Spec §7a — export/import. Export always excludes `sensitive` log entries
/// unless the caller explicitly opts in (§7's "never included unless
/// explicitly opted in per-action").
enum DataExportService {
    struct ExportBundle: Codable {
        var exportedAt: Date
        var habits: [Habit]
        var logEntries: [LogEntry]
        var readings: [Reading]
        var signals: [Signal]
        var reflections: [Reflection]
        var tags: [Tag]

        enum CodingKeys: String, CodingKey {
            case exportedAt = "exported_at"
            case habits
            case logEntries = "log_entries"
            case readings, signals, reflections, tags
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Writes the export to a temp file and returns its URL, ready for
    /// `ShareLink`. Caller decides whether to include sensitive entries.
    static func exportToFile(includeSensitive: Bool) async throws -> URL {
        let client = SupabaseService.shared.client

        var logEntryQuery = client.from("log_entry").select()
        if !includeSensitive {
            logEntryQuery = client.from("log_entry").select().neq("privacy_tier", value: "sensitive")
        }

        async let habits: [Habit] = client.from("habit").select().execute().value
        async let logEntries: [LogEntry] = logEntryQuery.execute().value
        async let readings: [Reading] = client.from("reading").select().execute().value
        async let signals: [Signal] = client.from("signal").select().execute().value
        async let reflections: [Reflection] = client.from("reflection").select().execute().value
        async let tags: [Tag] = client.from("tag").select().execute().value

        let bundle = ExportBundle(
            exportedAt: Date(),
            habits: try await habits,
            logEntries: try await logEntries,
            readings: try await readings,
            signals: try await signals,
            reflections: try await reflections,
            tags: try await tags
        )

        let data = try encoder.encode(bundle)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kadence-export-\(formatter.string(from: Date()))")
            .appendingPathExtension("json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Re-inserts a previously exported bundle. Uses `id`-based upsert so
    /// re-running an import (e.g. restoring after "Clear all data") doesn't
    /// fail on primary-key conflicts. `user_id` travels with each row as
    /// exported — RLS's `with check (auth.uid() = user_id)` means this only
    /// ever succeeds when importing back into the same account that
    /// exported it, which is the only scenario this feature supports.
    static func importBundle(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        let bundle = try decoder.decode(ExportBundle.self, from: data)
        let client = SupabaseService.shared.client

        // Habits first — log_entry rows reference habit_id via foreign key.
        if !bundle.habits.isEmpty {
            try await client.from("habit").upsert(bundle.habits).execute()
        }
        if !bundle.tags.isEmpty {
            try await client.from("tag").upsert(bundle.tags).execute()
        }
        if !bundle.logEntries.isEmpty {
            try await client.from("log_entry").upsert(bundle.logEntries).execute()
        }
        if !bundle.readings.isEmpty {
            try await client.from("reading").upsert(bundle.readings).execute()
        }
        if !bundle.signals.isEmpty {
            try await client.from("signal").upsert(bundle.signals).execute()
        }
        if !bundle.reflections.isEmpty {
            try await client.from("reflection").upsert(bundle.reflections).execute()
        }
    }

    /// Hard delete, scoped to the signed-in user's own rows (RLS makes this
    /// safe by construction). Does not touch `profile` — that's account
    /// settings, not logged data. PostgREST requires a filter on delete, so
    /// each call filters on an id no real row will ever have.
    static func clearAllData() async throws {
        let client = SupabaseService.shared.client
        let sentinel = "00000000-0000-0000-0000-000000000000"

        for table in ["log_entry", "reading", "signal", "reflection", "tag", "habit"] {
            try await client.from(table).delete().neq("id", value: sentinel).execute()
        }
    }
}

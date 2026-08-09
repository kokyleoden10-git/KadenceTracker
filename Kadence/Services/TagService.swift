import Foundation

/// Implements spec §6's case-insensitive tag matching in the app layer — the
/// database only enforces uniqueness per (user_id, canonical), it doesn't
/// normalize casing itself.
///
/// Display casing is always Title Case, regardless of how the tag was first
/// typed (product decision — supersedes the spec's older "first-used casing"
/// note).
enum TagService {
    static func resolve(_ raw: String) async throws -> Tag {
        let canonical = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !canonical.isEmpty else { throw TagError.empty }

        let matches: [Tag] = try await SupabaseService.shared.client
            .from("tag")
            .select()
            .eq("canonical", value: canonical)
            .limit(1)
            .execute()
            .value

        if let existing = matches.first {
            struct UsageBump: Encodable {
                let usageCount: Int
                enum CodingKeys: String, CodingKey { case usageCount = "usage_count" }
            }
            // Best-effort — a failed bump shouldn't block resolving the tag
            // itself, it just means autosuggest ranking is slightly stale.
            try? await SupabaseService.shared.client
                .from("tag")
                .update(UsageBump(usageCount: existing.usageCount + 1))
                .eq("id", value: existing.id)
                .execute()
            return existing
        }

        struct NewTag: Encodable {
            let canonical: String
            let display: String
            let usageCount: Int
            enum CodingKeys: String, CodingKey {
                case canonical, display
                case usageCount = "usage_count"
            }
        }

        let inserted: [Tag] = try await SupabaseService.shared.client
            .from("tag")
            .insert(NewTag(canonical: canonical, display: titleCase(canonical), usageCount: 1), returning: .representation)
            .select()
            .execute()
            .value

        guard let tag = inserted.first else { throw TagError.insertFailed }
        return tag
    }

    /// Prefix match for autosuggest (spec §6) — reuses existing tags rather
    /// than creating near-duplicates.
    static func suggestions(matching prefix: String, limit: Int = 5) async throws -> [Tag] {
        let canonicalPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !canonicalPrefix.isEmpty else { return [] }

        return try await SupabaseService.shared.client
            .from("tag")
            .select()
            .like("canonical", pattern: "\(canonicalPrefix)%")
            .order("usage_count", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Max 3 tags per Log Entry / Reading (spec §6).
    static func validate(_ tags: [String]) throws {
        guard tags.count <= 3 else { throw TagError.tooMany }
    }

    private static func titleCase(_ canonical: String) -> String {
        canonical
            .split(separator: " ")
            .map { $0.isEmpty ? "" : $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    enum TagError: Error {
        case empty
        case tooMany
        case insertFailed
    }
}

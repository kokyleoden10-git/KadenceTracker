import Foundation

/// An entry and its draws, fetched together via PostgREST's embedded
/// resources (`select=*,draw(*)`) rather than a second query per entry.
struct EntryWithDraws: Decodable, Identifiable {
    let entry: RemoteEntry
    let draws: [RemoteDraw]

    var id: UUID { entry.id }
    var dailyDraw: RemoteDraw? { draws.first { $0.role == .daily } }
    var jumperDraws: [RemoteDraw] { draws.filter { $0.role == .jumper } }

    private enum CodingKeys: String, CodingKey { case draw }

    /// RemoteEntry decodes its own keys from this same JSON object; the
    /// nested array comes from the embed, keyed by the table name.
    init(from decoder: Decoder) throws {
        entry = try RemoteEntry(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        draws = try container.decodeIfPresent([RemoteDraw].self, forKey: .draw) ?? []
    }
}

enum EntryService {
    private static let embed = "*, draw(*)"

    static func fetchAll() async throws -> [EntryWithDraws] {
        try await SupabaseService.shared.client
            .from("entry")
            .select(embed)
            .order("date", ascending: false)
            .execute()
            .value
    }

    static func fetchForDate(_ date: Date = Date()) async throws -> EntryWithDraws? {
        let rows: [EntryWithDraws] = try await SupabaseService.shared.client
            .from("entry")
            .select(embed)
            .eq("date", value: SupabaseDate.string(date))
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    struct EntryInput: Encodable {
        var userId: UUID
        var date: String
        var deckId: UUID?
        var skipped: Bool
        var morningRead: String?
        var eveningReflection: String?
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case date, skipped
            case userId = "user_id"
            case deckId = "deck_id"
            case morningRead = "morning_read"
            case eveningReflection = "evening_reflection"
            case updatedAt = "updated_at"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(userId, forKey: .userId)
            try container.encode(date, forKey: .date)
            try container.encode(deckId, forKey: .deckId)
            try container.encode(skipped, forKey: .skipped)
            try container.encode(morningRead, forKey: .morningRead)
            try container.encode(eveningReflection, forKey: .eveningReflection)
            try container.encode(updatedAt, forKey: .updatedAt)
        }
    }

    /// Relies on the (user_id, date) unique constraint — one entry per day,
    /// and saving again updates that day rather than adding a second row.
    @discardableResult
    static func upsert(_ input: EntryInput) async throws -> RemoteEntry {
        let rows: [RemoteEntry] = try await SupabaseService.shared.client
            .from("entry")
            .upsert(input, onConflict: "user_id,date", returning: .representation)
            .select()
            .execute()
            .value
        guard let entry = rows.first else { throw EntryError.upsertFailed }
        return entry
    }

    struct DrawInput: Encodable {
        var userId: UUID
        var entryId: UUID
        var cardId: String?
        var cardName: String
        var role: DrawRole
        var reversed: Bool
        var resonanceTier: String?
        var resonanceNote: String?

        enum CodingKeys: String, CodingKey {
            case role, reversed
            case userId = "user_id"
            case entryId = "entry_id"
            case cardId = "card_id"
            case cardName = "card_name"
            case resonanceTier = "resonance_tier"
            case resonanceNote = "resonance_note"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(userId, forKey: .userId)
            try container.encode(entryId, forKey: .entryId)
            try container.encode(cardId, forKey: .cardId)
            try container.encode(cardName, forKey: .cardName)
            try container.encode(role, forKey: .role)
            try container.encode(reversed, forKey: .reversed)
            try container.encode(resonanceTier, forKey: .resonanceTier)
            try container.encode(resonanceNote, forKey: .resonanceNote)
        }
    }

    static func addDraws(_ inputs: [DrawInput]) async throws {
        guard !inputs.isEmpty else { return }
        try await SupabaseService.shared.client
            .from("draw")
            .insert(inputs)
            .execute()
    }

    /// Deleting the entry cascades to its draws, returning the day to
    /// "nothing logged" rather than leaving an empty shell behind.
    static func deleteEntry(id: UUID) async throws {
        try await SupabaseService.shared.client
            .from("entry")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// v3 spec's Tier 3 reference — every past draw of one card, newest
    /// first, with the entry it belonged to. Retrieval, not statistics, so
    /// it's useful from the second occurrence onward.
    static func history(cardId: String) async throws -> [EntryWithDraws] {
        let rows: [EntryWithDraws] = try await SupabaseService.shared.client
            .from("entry")
            .select(embed)
            .order("date", ascending: false)
            .execute()
            .value
        return rows.filter { $0.draws.contains { $0.cardId == cardId } }
    }

    enum EntryError: Error { case upsertFailed }
}

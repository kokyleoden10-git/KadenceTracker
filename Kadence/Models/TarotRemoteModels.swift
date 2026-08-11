import Foundation

/// Supabase-backed counterparts to the SwiftData models in TarotModels.
///
/// Two parallel sets exist deliberately and temporarily: the SwiftData ones
/// still drive DrawView while this layer is built out, and the on-device
/// data is migrated across before the SwiftData ones are retired. Naming is
/// `Remote*` only for that overlap window.
///
/// Dates use plain `yyyy-MM-dd` strings, matching the habit models — a
/// Postgres `date` column has no time or timezone, and decoding one into a
/// Swift `Date` is what broke the profile screen earlier.

struct RemoteDeck: Codable, Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var name: String
    var tradition: String
    var usesReversals: Bool
    var createdAt: Date
    var archivedAt: Date?

    /// Tradition is stored as text, so an unrecognised value degrades to
    /// `.other` rather than failing the whole decode.
    var traditionValue: Tradition { Tradition(rawValue: tradition) ?? .other }

    enum CodingKeys: String, CodingKey {
        case id, name, tradition
        case userId = "user_id"
        case usesReversals = "uses_reversals"
        case createdAt = "created_at"
        case archivedAt = "archived_at"
    }
}

struct RemoteEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var date: String
    var deckId: UUID?
    var skipped: Bool
    var morningRead: String?
    var eveningReflection: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, date, skipped
        case userId = "user_id"
        case deckId = "deck_id"
        case morningRead = "morning_read"
        case eveningReflection = "evening_reflection"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RemoteDraw: Codable, Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var entryId: UUID
    var cardId: String?
    var cardName: String
    var role: DrawRole
    var reversed: Bool
    var resonanceTier: String?
    var resonanceNote: String?
    var createdAt: Date

    var card: TarotCard? { cardId.flatMap { CardCatalog.card(id: $0) } }

    enum CodingKeys: String, CodingKey {
        case id, role, reversed
        case userId = "user_id"
        case entryId = "entry_id"
        case cardId = "card_id"
        case cardName = "card_name"
        case resonanceTier = "resonance_tier"
        case resonanceNote = "resonance_note"
        case createdAt = "created_at"
    }
}

struct RemoteNatalChart: Codable, Identifiable, Hashable {
    /// user_id is the table's primary key — one chart per account, enforced
    /// by the schema rather than by query order.
    var id: UUID { userId }
    let userId: UUID
    var sun: ZodiacSign
    var moon: ZodiacSign
    var mercury: ZodiacSign
    var venus: ZodiacSign
    var mars: ZodiacSign
    var jupiter: ZodiacSign
    var saturn: ZodiacSign
    var uranus: ZodiacSign
    var neptune: ZodiacSign
    var pluto: ZodiacSign
    var ascendant: ZodiacSign
    var midheaven: ZodiacSign
    var birthDateDescription: String?
    var birthTimeDescription: String?
    var birthLocationDescription: String?
    var userNote: String?

    enum CodingKeys: String, CodingKey {
        case sun, moon, mercury, venus, mars, jupiter, saturn, uranus, neptune, pluto
        case ascendant, midheaven
        case userId = "user_id"
        case birthDateDescription = "birth_date_description"
        case birthTimeDescription = "birth_time_description"
        case birthLocationDescription = "birth_location_description"
        case userNote = "user_note"
    }
}

struct RemoteDayEnergy: Codable, Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var date: String
    /// 1 low, 2 steady, 3 high. Constrained in the schema too.
    var value: Int

    enum CodingKeys: String, CodingKey {
        case id, date, value
        case userId = "user_id"
    }
}

/// Shared with the habit services' convention of formatting dates once.
enum SupabaseDate {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(_ date: Date = Date()) -> String {
        formatter.string(from: date)
    }

    static func date(_ string: String) -> Date? {
        formatter.date(from: string)
    }
}

import Foundation

enum NatalChartService {
    /// At most one row exists per account — user_id is the primary key.
    static func fetch() async throws -> RemoteNatalChart? {
        let rows: [RemoteNatalChart] = try await SupabaseService.shared.client
            .from("natal_chart")
            .select()
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    struct ChartInput: Encodable {
        var userId: UUID
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

        /// Explicit encode so clearing an optional sends null instead of
        /// omitting the key — same lesson as ProfileUpdate.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(userId, forKey: .userId)
            try container.encode(sun, forKey: .sun)
            try container.encode(moon, forKey: .moon)
            try container.encode(mercury, forKey: .mercury)
            try container.encode(venus, forKey: .venus)
            try container.encode(mars, forKey: .mars)
            try container.encode(jupiter, forKey: .jupiter)
            try container.encode(saturn, forKey: .saturn)
            try container.encode(uranus, forKey: .uranus)
            try container.encode(neptune, forKey: .neptune)
            try container.encode(pluto, forKey: .pluto)
            try container.encode(ascendant, forKey: .ascendant)
            try container.encode(midheaven, forKey: .midheaven)
            try container.encode(birthDateDescription, forKey: .birthDateDescription)
            try container.encode(birthTimeDescription, forKey: .birthTimeDescription)
            try container.encode(birthLocationDescription, forKey: .birthLocationDescription)
            try container.encode(userNote, forKey: .userNote)
        }
    }

    /// Upsert on the primary key, so editing the chart replaces it rather
    /// than adding a second one.
    static func save(_ input: ChartInput) async throws {
        try await SupabaseService.shared.client
            .from("natal_chart")
            .upsert(input, onConflict: "user_id")
            .execute()
    }
}

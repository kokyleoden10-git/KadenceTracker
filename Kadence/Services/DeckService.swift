import Foundation

enum DeckService {
    static func fetchActive() async throws -> [RemoteDeck] {
        try await SupabaseService.shared.client
            .from("deck")
            .select()
            .is("archived_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    struct DeckInput: Encodable {
        var userId: UUID
        var name: String
        var tradition: String
        var usesReversals: Bool

        enum CodingKeys: String, CodingKey {
            case name, tradition
            case userId = "user_id"
            case usesReversals = "uses_reversals"
        }
    }

    @discardableResult
    static func create(name: String, tradition: Tradition, usesReversals: Bool) async throws -> RemoteDeck {
        let input = DeckInput(
            userId: try await SupabaseService.shared.requireUserId(),
            name: name,
            tradition: tradition.rawValue,
            usesReversals: usesReversals
        )
        let rows: [RemoteDeck] = try await SupabaseService.shared.client
            .from("deck")
            .insert(input, returning: .representation)
            .select()
            .execute()
            .value
        guard let deck = rows.first else { throw DeckError.insertFailed }
        return deck
    }

    enum DeckError: Error { case insertFailed }
}

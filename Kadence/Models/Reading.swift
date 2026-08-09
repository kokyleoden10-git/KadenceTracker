import Foundation

enum ReadingType: String, Codable {
    case tarot, astrology, other
}

struct Reading: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var date: Date
    var type: ReadingType
    var deck: String?
    var spread: String?
    var cards: [String]?
    var notes: String
    var tags: [String]
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, date, type, deck, spread, cards, notes, tags
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

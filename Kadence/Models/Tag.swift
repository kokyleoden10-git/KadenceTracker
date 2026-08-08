import Foundation

struct Tag: Codable, Identifiable {
    let id: UUID
    var canonical: String
    var display: String
    var usageCount: Int

    enum CodingKeys: String, CodingKey {
        case id, canonical, display
        case usageCount = "usage_count"
    }
}

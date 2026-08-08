import Foundation

struct Signal: Codable, Identifiable {
    let id: UUID
    var date: Date
    var metric: String
    var value: Double
    var source: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, date, metric, value, source
        case createdAt = "created_at"
    }
}

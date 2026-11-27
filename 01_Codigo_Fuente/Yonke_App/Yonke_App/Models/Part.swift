import Foundation

enum PartCondition: String, Codable {
    case excellent
    case good
    case fair
    case broken
}

struct Part: Identifiable, Codable {
    let id: UUID
    let vehicleId: UUID
    let name: String
    let description: String?
    let category: String
    let condition: PartCondition
    let price: Double
    let isSold: Bool
    let createdAt: Date
    let updatedAt: Date
}

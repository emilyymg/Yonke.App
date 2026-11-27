import Foundation

enum VehicleStatus: String, Codable {
    case received
    case processing
    case dismantled
}

struct Vehicle: Identifiable, Codable, Hashable {
    let id: UUID
    let make: String
    let model: String
    let year: Int
    let vin: String?
    let status: VehicleStatus
    let purchaseDate: Date
    let createdAt: Date
    let updatedAt: Date
}

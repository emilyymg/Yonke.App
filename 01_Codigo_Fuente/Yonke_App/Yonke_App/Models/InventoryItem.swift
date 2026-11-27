import Foundation

struct InventoryItem: Identifiable, Codable {
    let id: UUID
    let partId: UUID?
    let sku: String
    let quantity: Int
    let location: String
    let createdAt: Date
    let updatedAt: Date
}

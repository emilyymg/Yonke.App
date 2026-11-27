import Foundation

enum UserRole: String, Codable {
    case admin
    case employee
}

struct User: Identifiable, Codable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
    let role: UserRole
    let createdAt: Date
    let updatedAt: Date
}

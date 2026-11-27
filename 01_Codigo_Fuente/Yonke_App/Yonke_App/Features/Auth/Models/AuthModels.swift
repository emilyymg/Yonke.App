import Foundation

struct LoginRequest: Encodable {
    let email: String
    let contrasena: String
}

struct LoginResponse: Decodable {
    let token: String
    let user: AuthUser
}

struct AuthUser: Codable, Equatable {
    let id: String
    let nombre: String
    let email: String
}

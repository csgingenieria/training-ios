import Foundation

struct AuthLoginResponseDTO: Sendable {
    let access_token: String
    let refresh_token: String
    let token_type: String
    let expires_in: Int
    let user: UserDTO
}

nonisolated extension AuthLoginResponseDTO: Decodable {}

struct RefreshResponseDTO: Sendable {
    let access_token: String
    let expires_in: Int
}

nonisolated extension RefreshResponseDTO: Decodable {}

import Foundation

struct AuthLoginResponseDTO: Decodable, Sendable {
    let access_token: String
    let refresh_token: String
    let token_type: String
    let expires_in: Int
    let user: UserDTO
}

struct RefreshResponseDTO: Decodable, Sendable {
    let access_token: String
    let expires_in: Int
}

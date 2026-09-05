import Foundation

struct UserDTO: Identifiable, Hashable, Sendable {
    let id: String
    let email: String
    let name: String
    let role: String
    let organizationId: String?
    let studentProfileId: String?

    var isStudent: Bool { role == "STUDENT" }
    var isAdminLike: Bool { ["ADMIN", "SUPER_ADMIN", "MANAGER"].contains(role) }
}

nonisolated extension UserDTO: Decodable {}

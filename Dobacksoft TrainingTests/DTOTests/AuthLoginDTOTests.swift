import Testing
import Foundation

@testable import Dobacksoft_Training

struct AuthLoginDTOTests {
    @Test func decodeLoginResponse() throws {
        let dto: AuthLoginResponseDTO = try JSONFixture.decode("login-response")
        #expect(dto.access_token == "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiMDAxMjM0NTY3ODkiLCJleHAiOjk5OTk5OTk5OTl9.test-signature")
        #expect(!dto.refresh_token.isEmpty)
        #expect(dto.token_type == "Bearer")
        #expect(dto.expires_in == 3600)
        #expect(dto.user.id == "00123456789")
        #expect(dto.user.email == "juan.perez@cmadrid.es")
        #expect(dto.user.name == "Juan Pérez")
        #expect(dto.user.role == "STUDENT")
        #expect(dto.user.organizationId == "org-cmadrid-001")
        #expect(dto.user.studentProfileId == "student-001")
    }

    @Test func decodeUserDTOHelpers() throws {
        let dto: AuthLoginResponseDTO = try JSONFixture.decode("login-response")
        #expect(dto.user.isStudent == true)
        #expect(dto.user.isAdminLike == false)
    }

    @Test func decodeAdminUserHelpers() throws {
        let json = """
        {
            "id": "admin-001",
            "email": "admin@cmadrid.es",
            "name": "Admin",
            "role": "ADMIN",
            "organizationId": "org-cmadrid-001",
            "studentProfileId": null
        }
        """.data(using: .utf8)!
        let user = try JSONDecoder().decode(UserDTO.self, from: json)
        #expect(user.isStudent == false)
        #expect(user.isAdminLike == true)
    }
}

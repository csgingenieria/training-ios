import Testing
import Foundation

@testable import Dobacksoft_Training

struct StudentProfileDTOTests {
    @Test func decodeFullProfile() throws {
        let dto: StudentProfileDTO = try JSONFixture.decode("student-profile")

        // User
        #expect(dto.user.id == "stu-001")
        #expect(dto.user.name == "María García")
        #expect(dto.user.role == "STUDENT")
        #expect(dto.user.isStudent == true)

        // Standings
        #expect(dto.standings.count == 2)
        let first = dto.standings[0]
        #expect(first.convocatoriaId == "conv-001")
        #expect(first.name == "Convocatoria 2026")
        #expect(first.position == 5)
        #expect(first.plazas == 50)
        #expect(first.score == 8.25)
        #expect(first.attemptsCompleted == 5)
        #expect(first.attemptsTotal == 6)
        #expect(first.status == "ACTIVE")

        // Attempts (lista completa; incluye sin score — diferente de attemptsCompleted)
        #expect(dto.attempts.count == 2)
        #expect(dto.attempts[0].id == "atm-101")
        #expect(dto.attempts[0].score == 8.40)
        #expect(dto.attempts[0].dataQuality == "HIGH")
        #expect(dto.attempts[1].score == nil)
        #expect(dto.attempts[1].dataQuality == "LOW")
    }

    /// Gotcha documentado: `attempts.count` no es lo mismo que la suma de
    /// `standings[*].attemptsCompleted`. Validamos que el DTO mantiene la
    /// distinción — la fixture tiene 1 intento con score y 1 sin score,
    /// totales del standing distintos.
    @Test func attemptsCountIsIndependentFromAttemptsCompleted() throws {
        let dto: StudentProfileDTO = try JSONFixture.decode("student-profile")
        let countCompletedFromStandings = dto.standings.reduce(0) { $0 + $1.attemptsCompleted }
        // 2 intentos en la lista, suma standing = 9 (5 + 4). Son métricas distintas.
        #expect(dto.attempts.count != countCompletedFromStandings)
    }

    @Test func decodeMinimalProfile() throws {
        let json = """
        {
            "user": {
                "id": "stu-999",
                "email": "x@y.com",
                "name": "X",
                "role": "STUDENT",
                "organizationId": "org-1",
                "studentProfileId": null
            },
            "standings": [],
            "attempts": []
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(StudentProfileDTO.self, from: json)
        #expect(dto.standings.isEmpty)
        #expect(dto.attempts.isEmpty)
        #expect(dto.user.studentProfileId == nil)
    }
}

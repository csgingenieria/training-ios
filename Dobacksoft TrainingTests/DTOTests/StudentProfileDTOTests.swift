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

/// The shape `GET /api/v1/students/{id}/profile` actually returns, verified
/// against staging with the instructor account on 2026-09-07.
///
/// The profile carries each standing's grade composition, and this view was the
/// last place that ignored it: an instructor opened a candidate and read «0,85»
/// with nothing to explain the number. It is the screen from which a candidate
/// gets called.
struct ProfileCompositionTests {
    private func profile() throws -> StudentProfileDTO {
        let json = Data("""
        {
          "user": {
            "id": "c-uno", "name": "Nombre Aspirante",
            "email": "nombre@oposicion.cmadrid.es", "role": "STUDENT",
            "organizationId": "org-1", "studentProfileId": null
          },
          "standings": [
            {
              "convocatoriaId": "conv-1", "name": "Oposición Conductores 2026",
              "position": 2, "totalCandidates": 4, "status": "ACTIVE",
              "score": 0.85, "attemptsCompleted": 1, "attemptsTotal": 1,
              "completedRequired": 1, "pendingRequired": 9, "scoreOfCompleted": 8.5,
              "requiredRoutes": ["1A","1B","2A1","2A2","2A3","2B1","2B2","2B3","3A","3B"]
            }
          ],
          "attempts": [
            {
              "id": "at-1", "score": 8.5, "dataQuality": "HIGH",
              "createdAt": "2026-09-03T10:44:49.050604Z",
              "route": {"id": "2A2", "label": "2A2", "name": "2A2 Un recorrido", "categoria": "EXAMEN"}
            }
          ]
        }
        """.utf8)
        return try JSONDecoder().decode(StudentProfileDTO.self, from: json)
    }

    @Test func theProfileCarriesTheComposition() throws {
        let standing = try #require(try profile().standings.first)
        let composition = try #require(standing.composition)

        #expect(composition.totalRequired == 10)
        #expect(composition.completedRequired == 1)
        #expect(composition.pendingRequired == 9)
        #expect(composition.scoreOfCompleted == 8.5)
        #expect(composition.hasPendingRoutes)
    }

    /// The arithmetic that makes «0,85» unreadable on its own: an 8,5 average
    /// over one of ten required routes, with nine zeros.
    @Test func theGradeIsTheAverageOverEveryRequiredRoute() throws {
        let standing = try #require(try profile().standings.first)
        let composition = try #require(standing.composition)
        let average = try #require(composition.scoreOfCompleted)

        let official = average * Double(composition.completedRequired) / Double(composition.totalRequired)
        #expect(abs(official - standing.score) < 0.01)
    }

    /// The candidate's own attempt keeps one decimal; the aggregate keeps two.
    @Test func eachNumberIsWrittenInItsOwnPrecision() throws {
        let dto = try profile()
        let attempt = try #require(dto.attempts.first)
        let standing = try #require(dto.standings.first)

        #expect(ScoreFormat.attempt(try #require(attempt.score)) == "8,5")
        #expect(ScoreFormat.aggregate(standing.score) == "0,85")
    }

    /// A payload from before the contract carried the composition must still
    /// decode: the app outlives a backend release.
    @Test func olderProfilesStillDecode() throws {
        let json = Data("""
        {
          "user": {"id": "c", "name": "X", "email": "x@y.es", "role": "STUDENT",
                   "organizationId": "o", "studentProfileId": null},
          "standings": [{"convocatoriaId": "c1", "name": "N", "position": 1,
                         "totalCandidates": 2, "status": "ACTIVE", "score": 7.0,
                         "attemptsCompleted": 1, "attemptsTotal": 1}],
          "attempts": []
        }
        """.utf8)

        let dto = try JSONDecoder().decode(StudentProfileDTO.self, from: json)

        #expect(dto.standings.first?.composition == nil)
        #expect(dto.standings.first?.score == 7.0)
    }
}

import Testing
import Foundation

@testable import Dobacksoft_Training

struct StandingDTOTests {
    @Test func decodeStanding() throws {
        let dto: StandingDTO = try JSONFixture.decode("standing")
        #expect(dto.convocatoriaId == "conv-001")
        #expect(dto.position == 3)
        #expect(dto.totalCandidates == 42)
        #expect(dto.plazas == 50)
        #expect(dto.score == 7.5)
        #expect(dto.attemptsCompleted == 3)
        #expect(dto.attemptsTotal == 5)
        #expect(dto.status == "ACTIVE")
    }

    @Test func standingIsWithinAvailableSeats() throws {
        let dto: StandingDTO = try JSONFixture.decode("standing")
        #expect(dto.isWithinAvailableSeats == true) // position 3 <= plazas 50
    }

    @Test func standingOutsideSeats() throws {
        let json = """
        {
            "convocatoriaId": "conv-001",
            "position": 55,
            "totalCandidates": 60,
            "plazas": 50,
            "score": 5.0,
            "attemptsCompleted": 2,
            "attemptsTotal": 5,
            "status": "ACTIVE"
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(StandingDTO.self, from: json)
        #expect(dto.isWithinAvailableSeats == false) // position 55 > plazas 50
    }
}

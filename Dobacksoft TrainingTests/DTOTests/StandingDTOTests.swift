import Testing
import Foundation

@testable import Dobacksoft_Training

struct StandingDTOTests {
    @Test func decodeStanding() throws {
        let dto: StandingDTO = try JSONFixture.decode("standing")
        #expect(dto.convocatoriaId == "conv-001")
        #expect(dto.position == 3)
        #expect(dto.totalCandidates == 42)
        #expect(dto.score == 7.5)
        #expect(dto.attemptsCompleted == 3)
        #expect(dto.attemptsTotal == 5)
        #expect(dto.status == "ACTIVE")
    }

    /// The backend still returns `plazas` as a compatibility mirror of
    /// `totalCandidates` (marked "Release N" in its services layer) while older
    /// clients are retired. The field carries no meaning: cupos were removed
    /// from the domain, and `CMADRID-ENTREGA.md` v1.1 states to the customer
    /// that the system does not manage them.
    ///
    /// Decoding must ignore it rather than fail, and the DTO must not surface
    /// it — a value that cannot be read cannot be rendered.
    @Test func legacyPlazasFieldIsIgnored() throws {
        let json = Data("""
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
        """.utf8)

        let dto = try JSONDecoder().decode(StandingDTO.self, from: json)

        #expect(dto.position == 55)
        #expect(dto.totalCandidates == 60)
    }
}

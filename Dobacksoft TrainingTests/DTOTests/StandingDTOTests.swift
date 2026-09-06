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

    /// Regression guard.
    ///
    /// The backend docstring still tells clients to derive the cut-off line:
    /// "el cliente calcula `position <= plazas` localmente si lo necesita".
    /// Since `plazas` now mirrors `totalCandidates`, that comparison is always
    /// true — an obedient client would mark every single candidate as being
    /// within a seat that no longer exists.
    ///
    /// Reflection is used on purpose: it fails if anyone reintroduces the field
    /// through a model regeneration or a well-meaning pull request.
    @Test func noStandingTypeExposesSeats() {
        let standing = StandingDTO(
            convocatoriaId: "c",
            position: 1,
            totalCandidates: 10,
            score: 8.0,
            attemptsCompleted: 2,
            attemptsTotal: 3,
            status: "ACTIVE"
        )
        let profile = ProfileStandingDTO(
            convocatoriaId: "c",
            name: "Convocatoria",
            position: 1,
            totalCandidates: 10,
            score: 8.0,
            attemptsCompleted: 2,
            attemptsTotal: 3,
            status: "ACTIVE"
        )
        let convocatoria = ConvocatoriaSummaryDTO(
            id: "c",
            name: "Convocatoria",
            description: nil,
            status: "OPEN",
            totalCandidates: 10,
            closedAt: nil,
            updatedAt: nil
        )

        let banned = ["plaza", "cupo", "seat", "cutoff", "corte"]
        for subject in [Mirror(reflecting: standing), Mirror(reflecting: profile), Mirror(reflecting: convocatoria)] {
            for child in subject.children {
                let label = (child.label ?? "").lowercased()
                for word in banned {
                    #expect(!label.contains(word), "«\(label)» reintroduce el cupo")
                }
            }
        }
    }
}

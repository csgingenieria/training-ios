import Testing
import Foundation

@testable import Dobacksoft_Training

struct AttemptDetailDTOTests {
    @Test func decodeAttemptDetail() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")
        #expect(dto.id == "attempt-001")
        #expect(dto.candidate?.name == "Juan Pérez")
        #expect(dto.route?.label == "Recorrido A")
        #expect(dto.score == 7.5)
        #expect(dto.dataQuality == "HIGH")
        #expect(dto.convocatoriaId == "conv-001")
    }

    /// `family` is the Spanish display label the backend composes, not a
    /// machine key. The fixture used to claim `"estabilidad"`, so the suite was
    /// certifying a contract that does not exist.
    @Test func decodeScoreBreakdown() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")
        #expect(dto.scoreBreakdown.count == 5)

        let estabilidad = dto.scoreBreakdown[0]
        #expect(estabilidad.family == "Estabilidad (deducciones)")
        #expect(estabilidad.obtained == 4.2)
        #expect(estabilidad.max == 5.0)
    }

    /// A component carrying no weight on this route arrives unmeasured, and
    /// must never render as a zero the candidate scored.
    @Test func unweightedComponentIsNotMeasured() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")
        let frenoMotor = dto.scoreBreakdown[3]
        #expect(frenoMotor.family == "Uso del freno motor")
        #expect(frenoMotor.presentation == .notMeasured)
    }

    /// A component that does count but whose value never arrived.
    @Test func weightedComponentWithoutValueIsMissingData() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")
        let allison = dto.scoreBreakdown[4]
        #expect(allison.family == "Uso de la caja Allison")
        #expect(allison.presentation == .missingData)
    }

    /// Legacy attempts still emit the retired four-family vocabulary through
    /// the same field. Decoding must not assume the D10-W labels.
    @Test func legacyFourFamilyBreakdownStillDecodes() throws {
        let json = Data("""
        [
          {"family": "Estabilidad", "obtained": 3.5, "max": 3.5},
          {"family": "Velocidad", "obtained": 2.0, "max": 3.0},
          {"family": "Conducción", "obtained": 2.0, "max": 2.5},
          {"family": "Ruta", "obtained": 0.5, "max": 1.0}
        ]
        """.utf8)

        let rows = try JSONDecoder().decode([AttemptScoreFamilyDTO].self, from: json)

        #expect(rows.count == 4)
        #expect(rows.allSatisfy { if case .measured = $0.presentation { true } else { false } })
    }

    @Test func decodeEvents() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")
        #expect(dto.events.count == 2)

        let event = dto.events[0]
        #expect(event.type == "EVT_01")
        #expect(event.confidence == "HIGH")
        #expect(event.source == "DOBACK_ELITE")
    }
}

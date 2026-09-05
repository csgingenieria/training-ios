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

    @Test func decodeScoreBreakdown() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")
        #expect(dto.scoreBreakdown.count == 3)

        let estabilidad = dto.scoreBreakdown[0]
        #expect(estabilidad.family == "estabilidad")
        #expect(estabilidad.obtained == 4.2)
        #expect(estabilidad.max == 5.0)
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

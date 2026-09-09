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

    // MARK: - El código del recorrido

    /// The code goes in front of the name, because that is what the route is
    /// called at the station: «el 2B3», not «Bajada Navacerrada a Collado
    /// Villalba». The sheet showed only the long name.
    @Test func theCodeIsShownWhenItAddsSomething() throws {
        let route = try JSONDecoder().decode(AttemptRouteDTO.self, from: Data("""
        { "id": "R-1", "label": "2B3", "name": "Bajada Navacerrada" }
        """.utf8))
        #expect(route.codeIfDistinct == "2B3")
    }

    /// **And not when the name already IS the code.** A route with no assigned
    /// name falls back to its code, and repeating it would give «2B3 · 2B3».
    @Test func theCodeIsNotRepeatedWhenItIsTheName() throws {
        let route = try JSONDecoder().decode(AttemptRouteDTO.self, from: Data("""
        { "id": "2B3", "label": "2B3" }
        """.utf8))
        #expect(route.displayName == "2B3")
        #expect(route.codeIfDistinct == nil)
    }

    /// Case differences are the same code: «2b3» and «2B3» would otherwise
    /// print twice.
    @Test func caseDoesNotMakeItADifferentCode() throws {
        let route = try JSONDecoder().decode(AttemptRouteDTO.self, from: Data("""
        { "id": "2b3", "label": "2B3", "name": "2b3" }
        """.utf8))
        #expect(route.codeIfDistinct == nil)
    }

    /// The sentinel is not a code.
    @Test func theSentinelIsNotACode() throws {
        let route = try JSONDecoder().decode(AttemptRouteDTO.self, from: Data("""
        { "id": "—", "label": "", "name": "Bajada Navacerrada" }
        """.utf8))
        #expect(route.codeIfDistinct == nil)
    }
}

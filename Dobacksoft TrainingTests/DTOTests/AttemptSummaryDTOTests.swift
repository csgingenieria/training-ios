import Testing
import Foundation

@testable import Dobacksoft_Training

struct AttemptSummaryDTOTests {
    @Test func decodeListWithMixedScoresAndRoutes() throws {
        let dto: MyAttemptsListDTO = try JSONFixture.decode("my-attempts")
        #expect(dto.items.count == 4)

        // Primer intento: completo, todos los campos.
        let first = dto.items[0]
        #expect(first.id == "atm-001")
        #expect(first.route?.id == "r-1")
        #expect(first.route?.label == "Recorrido A")
        #expect(first.score == 8.20)
        #expect(first.dataQuality == "HIGH")
        #expect(first.createdAt == "2026-06-09T09:15:00+00:00")

        // Tercer intento: route null, score null — caso real de attempt cerrado
        // sin score validable (data quality LOW).
        let third = dto.items[2]
        #expect(third.id == "atm-003")
        #expect(third.route == nil)
        #expect(third.score == nil)
        #expect(third.dataQuality == "LOW")
    }

    @Test func decodeEmptyList() throws {
        let json = """
        { "items": [] }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MyAttemptsListDTO.self, from: json)
        #expect(dto.items.isEmpty)
    }

    @Test func summaryIsIdentifiable() throws {
        let dto: MyAttemptsListDTO = try JSONFixture.decode("my-attempts")
        let ids = dto.items.map(\.id)
        #expect(Set(ids).count == ids.count, "Los ids deben ser únicos (necesario para Identifiable en List)")
    }
}

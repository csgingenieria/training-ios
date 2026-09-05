import Testing
import Foundation

@testable import Dobacksoft_Training

struct ConvocatoriaDTOTests {
    @Test func decodeConvocatoriasList() throws {
        let dto: ConvocatoriasListDTO = try JSONFixture.decode("convocatorias-list")
        #expect(dto.items.count == 2)

        let first = dto.items[0]
        #expect(first.id == "conv-001")
        #expect(first.name == "Convocatoria 2026 — Bomberos CMadrid")
        #expect(first.status == "OPEN")
        #expect(first.plazas == 50)
        #expect(first.totalCandidates == 42)
        #expect(first.closedAt == nil)
        #expect(first.updatedAt == "2026-05-20T10:30:00Z")
        #expect(first.description != nil)
    }

    @Test func decodeClosedConvocatoria() throws {
        let dto: ConvocatoriasListDTO = try JSONFixture.decode("convocatorias-list")
        let closed = dto.items[1]
        #expect(closed.status == "CLOSED")
        #expect(closed.closedAt == "2025-12-15T18:00:00Z")
    }

    @Test func convocatoriaIdentifiable() throws {
        let dto: ConvocatoriasListDTO = try JSONFixture.decode("convocatorias-list")
        let ids = Set(dto.items.map { $0.id })
        #expect(ids.count == 2)
    }
}

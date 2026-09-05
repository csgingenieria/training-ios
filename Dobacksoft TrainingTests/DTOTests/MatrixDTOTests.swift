import Testing
import Foundation

@testable import Dobacksoft_Training

struct MatrixDTOTests {
    @Test func decodeMatrix() throws {
        let dto: MatrixResponseDTO = try JSONFixture.decode("matrix")
        #expect(dto.convocatoria.id == "conv-001")
        #expect(dto.circuits.count == 2)
        #expect(dto.rows.count == 2)

        let firstCircuit = dto.circuits[0]
        #expect(firstCircuit.id == "RECORRIDO_A")
        #expect(firstCircuit.label == "Recorrido A")
    }

    @Test func decodeMatrixRow() throws {
        let dto: MatrixResponseDTO = try JSONFixture.decode("matrix")
        let firstRow = dto.rows[0]
        #expect(firstRow.candidate.name == "María García")
        #expect(firstRow.scores.count == 2)
        #expect(firstRow.scores[0].circuitId == "RECORRIDO_A")
        #expect(firstRow.scores[0].score == 9.0)
    }
}

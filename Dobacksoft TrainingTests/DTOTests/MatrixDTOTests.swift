import Testing
import Foundation

@testable import Dobacksoft_Training

struct MatrixDTOTests {
    @Test func decodeMatrix() throws {
        let dto: MatrixResponseDTO = try JSONFixture.decode("matrix")
        #expect(dto.convocatoria.id == "conv-001")
        // Tres columnas: dos recorridos reales y el hueco de los intentos
        // sin recorrido, que existe en producción y lleva nota.
        #expect(dto.circuits.count == 3)
        #expect(dto.rows.count == 2)

        let firstCircuit = dto.circuits[0]
        #expect(firstCircuit.id == "RECORRIDO_A")
        #expect(firstCircuit.label == "Recorrido A")
    }

    @Test func decodeMatrixRow() throws {
        let dto: MatrixResponseDTO = try JSONFixture.decode("matrix")
        let firstRow = dto.rows[0]
        #expect(firstRow.candidate.name == "María García")
        #expect(firstRow.scores.count == 3)
        #expect(firstRow.scores[0].circuitId == "RECORRIDO_A")
        #expect(firstRow.scores[0].score == 9.0)
    }
}

/// Attempts with no route assigned exist in production, with a grade. The
/// backend gives them an invented slot (`U00`, `U01`…) rather than dropping
/// them — hiding them would erase real attempts from the screen.
struct SyntheticCircuitTests {
    @Test func syntheticColumnsAreIdentified() throws {
        let dto: MatrixResponseDTO = try JSONFixture.decode("matrix")
        #expect(dto.circuits.contains { $0.isSynthetic })
        #expect(dto.circuits.filter { !$0.isSynthetic }.count == 2)
    }

    /// `U00` is a slot identifier, not a route name. Printing it makes the app
    /// claim a route exists that does not.
    @Test func theInventedIdentifierIsNeverShown() throws {
        let dto: MatrixResponseDTO = try JSONFixture.decode("matrix")
        let synthetic = try #require(dto.circuits.first { $0.isSynthetic })
        #expect(synthetic.displayLabel == "Sin recorrido")
        #expect(synthetic.displayLabel != synthetic.id)
    }

    @Test func realColumnsKeepTheirLabel() throws {
        let dto: MatrixResponseDTO = try JSONFixture.decode("matrix")
        let real = try #require(dto.circuits.first(where: { !$0.isSynthetic }))
        #expect(real.displayLabel == real.label)
    }

    /// Older responses without the flag are treated as real, which is what they
    /// were before the field existed.
    @Test func absentFlagMeansReal() throws {
        let json = Data(#"{"id": "2A1", "label": "Parque → Hoyo"}"#.utf8)
        let circuit = try JSONDecoder().decode(MatrixCircuitDTO.self, from: json)
        #expect(!circuit.isSynthetic)
        #expect(circuit.displayLabel == "Parque → Hoyo")
    }

    /// The synthetic column carries real grades and must not be dropped.
    @Test func syntheticColumnsStillCarryScores() throws {
        let dto: MatrixResponseDTO = try JSONFixture.decode("matrix")
        let row = try #require(dto.rows.first)
        let cell = row.scores.first { $0.circuitId == "U00" }
        #expect(cell?.score == 3.2)
    }
}

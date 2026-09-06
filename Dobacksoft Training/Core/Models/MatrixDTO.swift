import Foundation

// MARK: - Circuit

/// Una columna de la matriz.
struct MatrixCircuitDTO: Sendable, Identifiable {
    let id: String
    let label: String

    /// `true` cuando la columna no es un recorrido real.
    ///
    /// Los intentos sin recorrido asignado —existen en producción, y con nota—
    /// reciben un identificador inventado (`U00`, `U01`…). No se ocultan,
    /// porque esconderlos borraría intentos reales de la pantalla, pero
    /// tampoco pueden presentarse como si fueran el nombre de un recorrido.
    ///
    /// Opcional porque el contrato lo añadió después.
    let synthetic: Bool?

    var isSynthetic: Bool { synthetic == true }

    /// Cabecera de la columna.
    var displayLabel: String { isSynthetic ? "Sin recorrido" : label }
}

nonisolated extension MatrixCircuitDTO: Decodable {}

// MARK: - Candidate

struct MatrixCandidateDTO: Sendable, Identifiable {
    let id: String
    let name: String
}

nonisolated extension MatrixCandidateDTO: Decodable {}

// MARK: - Score

struct MatrixScoreDTO: Sendable {
    let circuitId: String
    let score: Double?
    let attemptId: String?
}

nonisolated extension MatrixScoreDTO: Decodable {}

// MARK: - Row

struct MatrixRowDTO: Sendable, Identifiable {
    let candidate: MatrixCandidateDTO
    let scores: [MatrixScoreDTO]

    var id: String { candidate.id }
}

nonisolated extension MatrixRowDTO: Decodable {}

// MARK: - Response

struct MatrixResponseDTO: Sendable {
    let convocatoria: ConvocatoriaSummaryDTO
    let circuits: [MatrixCircuitDTO]
    let rows: [MatrixRowDTO]
}

nonisolated extension MatrixResponseDTO: Decodable {}

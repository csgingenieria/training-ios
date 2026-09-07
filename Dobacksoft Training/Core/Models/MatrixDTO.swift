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

    /// `true` si la convocatoria exige este recorrido.
    ///
    /// Desde el arreglo de `get_matrix_data`, la matriz devuelve TODOS los
    /// exigidos, también los que nadie ha conducido. Este campo distingue una
    /// columna vacía porque está exigida y aún no consta conducida, de una que
    /// simplemente no forma parte del conjunto exigido.
    ///
    /// Opcional porque el contrato lo añadió después.
    let required: Bool?

    var isRequired: Bool { required == true }

    var isSynthetic: Bool { synthetic == true }

    /// Cabecera de la columna: el identificador corto.
    ///
    /// `label` trae ahora el nombre del recorrido —«2A2 Subida y bajada Cruz
    /// Verde»— y en una columna de tabla no cabe. El nombre completo va al
    /// nombre accesible, que es donde sí se puede leer entero.
    var displayLabel: String { isSynthetic ? "Sin recorrido" : id }

    /// Nombre completo del recorrido, para VoiceOver y para cualquier sitio
    /// donde quepa.
    var fullName: String { isSynthetic ? "Sin recorrido asignado" : label }
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

import Foundation

// MARK: - Circuit

struct MatrixCircuitDTO: Sendable, Identifiable {
    let id: String
    let label: String
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

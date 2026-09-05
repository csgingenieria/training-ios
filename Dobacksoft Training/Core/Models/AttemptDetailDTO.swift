import Foundation

struct AttemptCandidateDTO: Hashable, Sendable {
    let id: String?
    let name: String?
}

nonisolated extension AttemptCandidateDTO: Decodable {}

struct AttemptRouteDTO: Hashable, Sendable {
    let id: String?
    let label: String?
}

nonisolated extension AttemptRouteDTO: Decodable {}

struct AttemptScoreFamilyDTO: Hashable, Sendable, Identifiable {
    let family: String?
    let obtained: Double?
    let max: Double?

    var id: String { family ?? UUID().uuidString }
}

nonisolated extension AttemptScoreFamilyDTO: Decodable {}

struct AttemptEventDTO: Hashable, Sendable, Identifiable {
    let type: String?
    let severity: Double?  // backend devuelve 0..1
    let confidence: String? // "HIGH" / "LOW"
    let description: String?
    let timestamp: String?
    let source: String?

    var id: String { (type ?? "ev") + "-" + (timestamp ?? UUID().uuidString) }
}

nonisolated extension AttemptEventDTO: Decodable {}

struct AttemptDetailDTO: Sendable {
    let id: String?
    let candidate: AttemptCandidateDTO?
    let route: AttemptRouteDTO?
    let score: Double?
    let dataQuality: String?

    /// Calidad clasificada. `nil` cuando el backend no la envió o el valor es
    /// desconocido — en ese caso no se pinta insignia.
    var quality: DataQuality? { DataQuality(apiValue: dataQuality) }
    let scoreBreakdown: [AttemptScoreFamilyDTO]
    let events: [AttemptEventDTO]
    let convocatoriaId: String?
}

nonisolated extension AttemptDetailDTO: Decodable {}

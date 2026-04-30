import Foundation

struct AttemptCandidateDTO: Decodable, Hashable, Sendable {
    let id: String?
    let name: String?
}

struct AttemptRouteDTO: Decodable, Hashable, Sendable {
    let id: String?
    let label: String?
}

struct AttemptScoreFamilyDTO: Decodable, Hashable, Sendable, Identifiable {
    let family: String?
    let obtained: Double?
    let max: Double?

    var id: String { family ?? UUID().uuidString }
}

struct AttemptEventDTO: Decodable, Hashable, Sendable, Identifiable {
    let type: String?
    let severity: Double?  // backend devuelve 0..1
    let confidence: String? // "HIGH" / "LOW"
    let description: String?
    let timestamp: String?
    let source: String?

    var id: String { (type ?? "ev") + "-" + (timestamp ?? UUID().uuidString) }
}

struct AttemptDetailDTO: Decodable, Sendable {
    let id: String?
    let candidate: AttemptCandidateDTO?
    let route: AttemptRouteDTO?
    let score: Double?
    let dataQuality: String?
    let scoreBreakdown: [AttemptScoreFamilyDTO]
    let events: [AttemptEventDTO]
    let convocatoriaId: String?
}

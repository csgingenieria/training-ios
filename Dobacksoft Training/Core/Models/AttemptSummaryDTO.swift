import Foundation

struct AttemptSummaryDTO: Sendable, Identifiable, Hashable {
    let id: String
    let route: AttemptRouteDTO?
    let score: Double?
    let dataQuality: String?
    let createdAt: String?
}

nonisolated extension AttemptSummaryDTO: Decodable {}

struct MyAttemptsListDTO: Sendable {
    let items: [AttemptSummaryDTO]
}

nonisolated extension MyAttemptsListDTO: Decodable {}

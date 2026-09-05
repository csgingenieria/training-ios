import Foundation

struct AttemptSummaryDTO: Sendable, Identifiable, Hashable {
    let id: String
    let route: AttemptRouteDTO?
    let score: Double?
    let dataQuality: String?

    /// Calidad clasificada. `nil` cuando el backend no la envió o el valor es
    /// desconocido — en ese caso no se pinta insignia.
    var quality: DataQuality? { DataQuality(apiValue: dataQuality) }
    let createdAt: String?
}

nonisolated extension AttemptSummaryDTO: Decodable {}

struct MyAttemptsListDTO: Sendable {
    let items: [AttemptSummaryDTO]
}

nonisolated extension MyAttemptsListDTO: Decodable {}

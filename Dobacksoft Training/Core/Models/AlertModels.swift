import Foundation

/// Severidad de una alerta operativa de enriquecimiento Webfleet.
/// Mapeo backend: `error` = enrichment FAILED · `warning` = enrichment PARTIAL.
enum WebfletAlertSeverity: String, Sendable, Decodable {
    case error
    case warning

    /// Para casos forward-compat si el backend agrega valores nuevos.
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = WebfletAlertSeverity(rawValue: raw.lowercased()) ?? .unknown
    }
}

/// Alerta operativa de enriquecimiento Webfleet — respuesta de
/// `GET /api/v1/webfleet/alerts`. Fuente real: Attempts con
/// `webfleetEnrichmentStatus` FAILED/PARTIAL en la org del caller.
///
/// GDPR-safe por construcción: NO expone telemetría granular (kpisDriver,
/// HARSH_*) — solo el hecho del fallo + error técnico. `studentName` es PII
/// de identidad pero el manager ya tiene autorización para verla.
struct WebfletAlertDTO: Sendable, Hashable, Identifiable {
    let attemptId: String
    let severity: WebfletAlertSeverity
    let type: String
    let message: String?
    let studentName: String?
    let timestamp: String?

    /// `attemptId` es único en el feed (backend ordena por timestamp y dedupea
    /// por attempt), sirve como Identifiable.
    var id: String { attemptId }
}

nonisolated extension WebfletAlertDTO: Decodable {}

/// Respuesta completa de `GET /api/v1/webfleet/alerts`.
struct WebfletAlertsResponseDTO: Sendable {
    let items: [WebfletAlertDTO]
    let count: Int
}

nonisolated extension WebfletAlertsResponseDTO: Decodable {}

import Foundation

/// Resumen de una convocatoria.
///
/// Sin `plazas`: el sistema no gestiona cupos. El backend todavía lo envía como
/// espejo de `totalCandidates` por compatibilidad y aquí se descarta.
nonisolated struct ConvocatoriaSummaryDTO: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let status: String?
    let totalCandidates: Int
    let closedAt: String?
    let updatedAt: String?
}

nonisolated extension ConvocatoriaSummaryDTO: Decodable {}

nonisolated extension ConvocatoriaSummaryDTO {
    /// Una forma para el esqueleto de carga, no un dato.
    ///
    /// Va tapada con `.redacted(reason: .placeholder)` y oculta a VoiceOver, así
    /// que nada de esto se lee ni se oye — pero se escribe con cuidado igual:
    /// una cifra de relleno que se escapara a una pantalla sería una cifra
    /// inventada sobre una oposición, y este proyecto no inventa datos ni de
    /// mentira.
    static let placeholder = ConvocatoriaSummaryDTO(
        id: "placeholder",
        name: "Convocatoria",
        description: nil,
        status: nil,
        totalCandidates: 0,
        closedAt: nil,
        updatedAt: nil
    )
}

nonisolated struct ConvocatoriasListDTO: Sendable {
    let items: [ConvocatoriaSummaryDTO]
}

nonisolated extension ConvocatoriasListDTO: Decodable {}

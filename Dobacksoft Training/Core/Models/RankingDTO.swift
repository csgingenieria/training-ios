import Foundation

struct RankingCandidateDTO: Hashable, Sendable {
    let id: String?
    let name: String?

    /// Número con el que el aspirante se identifica en el kiosko. **No** es un
    /// cupo de la oposición: el sistema no gestiona plazas.
    let plaza: String?
}

nonisolated extension RankingCandidateDTO: Decodable {}

/// Una fila del ranking de una convocatoria.
struct RankingEntryDTO: Identifiable, Hashable, Sendable {
    /// Puesto en el orden de méritos, o `nil` si la persona no ha conducido.
    ///
    /// El backend emite `position: null` para todo inscrito sin nota
    /// (`remap_ranking_entry`). Cuando esto era un `Int` no opcional, un solo
    /// ausente hacía indecodificable el array entero y el instructor no veía el
    /// ranking, sino un error de formato. No volver a hacerlo obligatorio.
    let position: Int?

    let candidate: RankingCandidateDTO

    /// Nota tal y como llega. Para quien no ha conducido, el backend envía
    /// `0.0`; usar `displayScore` para no mostrarlo.
    let score: Double?

    let attemptsCompleted: Int
    let attemptsTotal: Int
    let attemptId: String?

    /// `true` si la persona ha conducido y entra en el orden de méritos.
    ///
    /// Opcional porque el contrato lo añadió después.
    let presented: Bool?

    /// `true` si comparte puesto con alguien por tener la misma nota.
    ///
    /// El backend usa numeración de competición: 1, 2, 2, 4. Sin este dato, dos
    /// filas con el mismo número parecen un error de la app.
    let tied: Bool?

    /// `true` cuando la persona está inscrita pero no ha conducido.
    ///
    /// Prefiere el dato del backend sobre la heurística. Derivarlo de la
    /// ausencia de puesto funcionaba, pero ataba la app a un detalle de
    /// implementación del ranking.
    var hasNotDriven: Bool {
        if let presented { return !presented }
        return position == nil
    }

    /// Nota que puede mostrarse, o `nil` si no hay ninguna que mostrar.
    ///
    /// El `0.0` que acompaña a un ausente no es una nota baja: nadie la midió.
    /// Pintarlo afirmaría sobre una persona, en una oposición pública, que se
    /// evaluó su conducción y salió mal.
    var displayScore: Double? { hasNotDriven ? nil : score }

    var id: String {
        let candidateId = candidate.id ?? "anon"
        return position.map { "\(candidateId)-\($0)" } ?? "\(candidateId)-sin-puesto"
    }
}

nonisolated extension RankingEntryDTO: Decodable {}

struct RankingResponseDTO: Sendable {
    let convocatoria: ConvocatoriaSummaryDTO
    let entries: [RankingEntryDTO]
}

nonisolated extension RankingResponseDTO: Decodable {}

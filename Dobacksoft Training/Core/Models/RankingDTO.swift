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

    /// `true` cuando la persona está inscrita pero no ha conducido.
    ///
    /// Derivado de la ausencia de puesto, que es el único indicio disponible
    /// hoy: el backend todavía no envía un campo `presentado`.
    var hasNotDriven: Bool { position == nil }

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

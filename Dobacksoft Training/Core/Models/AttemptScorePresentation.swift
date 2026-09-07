import Foundation

/// What goes where the grade goes, including when there is no grade.
///
/// An attempt with no score is a legitimate backend state — the app even has a
/// «Sin nota» filter for it — and both screens handled it by omission: the row
/// printed a dash and the sheet printed nothing, because the `if let score`
/// wrapped the whole hero.
///
/// The rule against that was already written, in the widget: «nunca un guion en
/// lugar de una cifra, nunca ‹te falta› nada» (`SnapshotCopy`), which even
/// ships the sentence. This type is how the screens follow the rule their own
/// widget states, and it reuses that sentence instead of coining a second way
/// to word the same absence.
nonisolated struct AttemptScorePresentation: Sendable, Equatable {
    let score: Double?

    init(score: Double?) {
        self.score = score
    }

    /// La cifra, o la frase que dice que no la hay.
    var heroText: String {
        guard let score else { return SnapshotCopy.notaNoDisponible }
        return ScoreFormat.attempt(score)
    }

    /// El «/10» acompaña a una cifra. Sobre una frase no significa nada.
    var showsScale: Bool { score != nil }

    /// Por qué no hay número, o `nil` cuando lo hay.
    ///
    /// Descriptivo y del lado del sistema. «No ha entregado» o «le falta» le
    /// atribuirían al aspirante una omisión que no consta: un intento sin nota
    /// puede serlo por datos inservibles, y el motivo no viaja en el contrato.
    var heroDetail: String? {
        score == nil ? "Este intento no tiene nota registrada." : nil
    }
}

extension AttemptSummaryDTO {
    /// `true` cuando hay nota, incluido un cero.
    ///
    /// La distinción que el guion destruía: «—» y «0,0» significan lo contrario
    /// para quien se presenta a una oposición, y los dos se podían llegar a ver.
    var hasScore: Bool { score != nil }

    /// Lo que la fila enseña en la columna de la nota.
    var rowScoreText: String {
        guard let score else { return "Sin nota" }
        return ScoreFormat.attempt(score)
    }
}

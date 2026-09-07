import Testing
import Foundation

@testable import Dobacksoft_Training

/// What goes where the grade goes when there is no grade.
///
/// An attempt with no score is a legitimate backend state — the app even has a
/// «Sin nota» filter for it — and both screens dealt with it by omission. The
/// row printed a dash, and the sheet printed nothing at all: the `if let score`
/// wrapped the whole hero, so a scoreless attempt opened on a card that simply
/// began somewhere else, with no number, no explanation and no quality badge
/// either, because the badge lived inside the same `if`.
///
/// The rule already existed and was already written down — in the widget:
/// «nunca un guion en lugar de una cifra, nunca ‹te falta› nada»
/// (`SnapshotCopy`), which even ships the sentence. The screens did not follow
/// the rule their own widget states.
struct AttemptScorePresentationTests {
    private func attempt(score: Double?) -> AttemptSummaryDTO {
        AttemptSummaryDTO(
            id: "a-1",
            route: nil,
            score: score,
            dataQuality: "HIGH",
            createdAt: "2026-09-07T10:00:00Z"
        )
    }

    // MARK: - La fila

    @Test func aScoredRowShowsItsNumber() {
        #expect(attempt(score: 8.5).rowScoreText == "8,5")
    }

    /// «Sin nota», not a dash. The words are already the app's own: they are
    /// what the attempts filter calls this exact case.
    @Test func aScorelessRowSaysSoInWords() {
        #expect(attempt(score: nil).rowScoreText == "Sin nota")
    }

    @Test func theRowNeverPrintsADashInPlaceOfAFigure() {
        #expect(attempt(score: nil).rowScoreText.contains("—") == false)
        #expect(attempt(score: nil).rowScoreText.contains("-") == false)
    }

    /// A real zero is a grade and must read as one. This is the case a dash
    /// destroys: «—» and «0,0» mean opposite things to someone sitting an
    /// examination, and both used to be reachable.
    @Test func aZeroIsAGradeAndNotAnAbsence() {
        #expect(attempt(score: 0).rowScoreText == "0,0")
        #expect(attempt(score: 0).hasScore)
        #expect(attempt(score: nil).hasScore == false)
    }

    // MARK: - El héroe de la ficha

    @Test func theSheetHeroShowsTheGradeWhenThereIsOne() {
        #expect(AttemptScorePresentation(score: 7.5).heroText == "7,5")
        #expect(AttemptScorePresentation(score: 7.5).showsScale, "el «/10» acompaña a una cifra")
    }

    /// The sentence comes from `SnapshotCopy`, not from a new string: the
    /// widget and the sheet must not word the same absence two ways.
    @Test func theSheetHeroStatesTheAbsence() {
        let sinNota = AttemptScorePresentation(score: nil)

        #expect(sinNota.heroText == SnapshotCopy.notaNoDisponible)
        #expect(sinNota.showsScale == false, "«/10» sobre una frase no significa nada")
    }

    /// Descriptive, not consoling, and it must not suggest the candidate failed
    /// to do something: the reason is on the system's side.
    @Test func theExplanationDoesNotBlameTheCandidate() throws {
        let detalle = try #require(AttemptScorePresentation(score: nil).heroDetail)

        #expect(detalle.contains("no tiene nota registrada"))
        for culpa in ["debe", "tiene que", "no ha", "falta"] {
            #expect(detalle.lowercased().contains(culpa) == false, "«\(culpa)» apunta al aspirante")
        }
    }

    @Test func aScoredSheetNeedsNoExplanation() {
        #expect(AttemptScorePresentation(score: 9.0).heroDetail == nil)
    }
}

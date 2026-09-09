import Testing
import Foundation

@testable import Dobacksoft_Training

/// The two figures the portal derives from the attempts and the app did not.
///
/// The card showed the grade and the attempt count while already holding
/// everything else: the last attempt's date and which route goes best and worst
/// come from the SAME list already loaded. Not one extra request.
struct AttemptHighlightsTests {
    private func attempt(
        route: String?, score: Double?, createdAt: String?, practice: Bool = false
    ) -> AttemptSummaryDTO {
        AttemptSummaryDTO(
            id: UUID().uuidString,
            route: AttemptRouteDTO(id: route, label: route, name: route, categoria: practice ? "PRACTICA" : "EXAMEN"),
            score: score,
            createdAt: createdAt
        )
    }

    // MARK: - La fecha de la última vuelta

    /// **The maximum by INSTANT, not the first of the list.** The list arrives
    /// sorted by date, but that is a property of the backend that can change
    /// without notice, and sorting here costs nothing.
    @Test func theLastAttemptIsTheLatestInstantAndNotTheFirstRow() {
        let fecha = AttemptHighlights.lastAttemptDate([
            attempt(route: "1A", score: 5, createdAt: "2026-09-01T10:00:00Z"),
            attempt(route: "2B", score: 6, createdAt: "2026-09-08T10:00:00Z"),
            attempt(route: "3C", score: 7, createdAt: "2026-09-04T10:00:00Z")
        ])
        #expect(fecha == "2026-09-08T10:00:00Z")
    }

    @Test func withNoDatesThereIsNoLastAttempt() {
        #expect(AttemptHighlights.lastAttemptDate([]) == nil)
        #expect(AttemptHighlights.lastAttemptDate([attempt(route: "1A", score: 5, createdAt: nil)]) == nil)
    }

    /// An unreadable timestamp is skipped rather than sinking the answer.
    @Test func anUnreadableDateIsSkipped() {
        let fecha = AttemptHighlights.lastAttemptDate([
            attempt(route: "1A", score: 5, createdAt: "ayer"),
            attempt(route: "2B", score: 6, createdAt: "2026-09-01T10:00:00Z")
        ])
        #expect(fecha == "2026-09-01T10:00:00Z")
    }

    // MARK: - Mejor y peor recorrido

    @Test func theBestAndWorstRoutesAreNamed() throws {
        let extremos = try #require(AttemptHighlights.bestAndWorst([
            attempt(route: "1A", score: 4.0, createdAt: nil),
            attempt(route: "2B", score: 9.0, createdAt: nil)
        ]))
        #expect(extremos.best.code == "2B")
        #expect(extremos.worst.code == "1A")
    }

    /// The BEST per route, not the last: two laps on one route and the good one
    /// is what represents it.
    @Test func aRouteIsRepresentedByItsBestLap() throws {
        let extremos = try #require(AttemptHighlights.bestAndWorst([
            attempt(route: "1A", score: 2.0, createdAt: nil),
            attempt(route: "1A", score: 8.0, createdAt: nil),
            attempt(route: "2B", score: 5.0, createdAt: nil)
        ]))
        #expect(extremos.best.code == "1A")
        #expect(extremos.best.score == 8.0)
    }

    /// **With one route there is nothing to compare**, and saying «best: 2B3 ·
    /// to improve: 2B3» informs of nothing. Same rule the «Mi progreso»
    /// extremes card already follows.
    @Test func withASingleRouteThereIsNothingToCompare() {
        #expect(AttemptHighlights.bestAndWorst([
            attempt(route: "1A", score: 4.0, createdAt: nil),
            attempt(route: "1A", score: 9.0, createdAt: nil)
        ]) == nil)
    }

    /// **Practice laps are left out.** They do not count towards the grade, and
    /// flagging as «to improve» a route that does not score sends someone to
    /// work where it does not help them.
    @Test func practiceLapsAreLeftOut() {
        #expect(AttemptHighlights.bestAndWorst([
            attempt(route: "1A", score: 9.0, createdAt: nil),
            attempt(route: "PRACT", score: 1.0, createdAt: nil, practice: true)
        ]) == nil, "solo queda un recorrido que puntúa, así que no hay extremos")
    }

    /// An ungraded lap contributes nothing: a nil score is «no consta», never
    /// a zero that would make its route the worst.
    @Test func anUngradedLapIsNotAZero() {
        #expect(AttemptHighlights.bestAndWorst([
            attempt(route: "1A", score: 9.0, createdAt: nil),
            attempt(route: "2B", score: nil, createdAt: nil)
        ]) == nil, "2B no tiene nota, así que no entra como el peor")
    }
}

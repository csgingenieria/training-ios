import Testing
import Foundation

@testable import Dobacksoft_Training

/// What gets shared out of an attempt.
///
/// The text used to be built inline in the view, which is why it drifted from
/// the screen: it named the route and the mark but not WHEN the attempt
/// happened, so two laps of the same route shared out as the same message. It
/// also shipped the backend's own quality code — «Calidad: HIGH», in English —
/// out of the app.
struct AttemptShareTextTests {
    private let fecha = "2026-09-06T09:15:00Z"

    @Test func theDateLeadsBecauseItIsWhatTellsTwoLapsApart() throws {
        let texto = AttemptShareText.build(
            candidateName: "Ana Ruiz",
            routeLabel: "R-04 Centro",
            score: 8.5,
            quality: nil,
            createdAt: fecha
        )
        let lineas = texto.split(separator: "\n").map(String.init)

        // The expected string comes from the formatter, not written by hand:
        // the timestamp is UTC and the line shows LOCAL time (09:15Z reads
        // 11:15 in Madrid), which is what the candidate needs and what a
        // hand-written expectation would turn into a machine-dependent test.
        // How the instant is rendered is pinned by APIDateTests; what this
        // asserts is that the date is there and that it leads.
        let esperada = try #require(APIDate.shortDateTime(fecha))
        #expect(lineas.first == "Intento Training · CMadrid")
        #expect(lineas.dropFirst().first == "Fecha: \(esperada)")
        #expect(!texto.contains(fecha), "el ISO en crudo no sale de la app")
    }

    /// Without a date there is no «Fecha:» line at all — not an empty one, and
    /// not a dash. A label with nothing after it reads like a bug.
    @Test func withoutADateThereIsNoDateLine() {
        let texto = AttemptShareText.build(
            candidateName: "Ana Ruiz",
            routeLabel: "R-04 Centro",
            score: 8.5,
            quality: nil,
            createdAt: nil
        )
        #expect(!texto.contains("Fecha"))
    }

    /// An unparseable timestamp behaves exactly like a missing one. The share
    /// sheet is not the place to surface a raw ISO string.
    @Test func anUnreadableTimestampIsTreatedAsMissing() {
        let texto = AttemptShareText.build(
            candidateName: nil,
            routeLabel: nil,
            score: nil,
            quality: nil,
            createdAt: "ayer por la mañana"
        )
        #expect(!texto.contains("Fecha"))
        #expect(!texto.contains("ayer"))
    }

    /// Every field is optional, and an attempt with nothing but its header
    /// still shares as one readable line rather than a pile of dashes.
    @Test func anEmptyAttemptSharesAsItsHeaderAlone() {
        let texto = AttemptShareText.build(
            candidateName: nil,
            routeLabel: nil,
            score: nil,
            quality: nil,
            createdAt: nil
        )
        #expect(texto == "Intento Training · CMadrid")
        #expect(!texto.contains("—"))
    }

    /// The mark carries its scale. A bare «8,5» shared into a chat says
    /// nothing about what it is out of.
    @Test func theMarkCarriesItsScale() {
        let texto = AttemptShareText.build(
            candidateName: nil,
            routeLabel: nil,
            score: 8.5,
            quality: nil,
            createdAt: nil
        )
        #expect(texto.contains("/10"))
    }

    /// The person is an «aspirante». The product called them three things at
    /// once — «Alumno» here, «candidatos» in the convocatoria metrics,
    /// «alumno» in the manager profile — and this is the one piece of copy
    /// that leaves the app. `scripts/check-ui-register.sh` now scans for the
    /// other nouns across every UI literal, including the ones inside a View
    /// body that no unit test can reach.
    @Test func thePersonIsCalledAspirante() {
        let texto = AttemptShareText.build(
            candidateName: "Ana Ruiz",
            routeLabel: nil,
            score: nil,
            quality: nil,
            createdAt: nil
        )
        #expect(texto.contains("Aspirante: Ana Ruiz"))
        #expect(!texto.contains("Alumno"))
    }

    /// The quality reads as a sentence, not as a backend code. It shared out
    /// as «Calidad: HIGH» — an enum value from the API, in English, in the one
    /// piece of copy that leaves the app.
    @Test func theQualityIsALabelAndNotABackendCode() {
        let texto = AttemptShareText.build(
            candidateName: nil,
            routeLabel: nil,
            score: nil,
            quality: .high,
            createdAt: nil
        )
        #expect(texto.contains("Calidad alta"))
        #expect(!texto.contains("HIGH"))
    }

    /// And what leaves the app never carries a verdict.
    @Test func whatLeavesTheAppStaysWithinArticle22() {
        let texto = AttemptShareText.build(
            candidateName: "Ana Ruiz",
            routeLabel: "R-04 Centro",
            score: 8.5,
            quality: .high,
            createdAt: fecha
        ).lowercased()

        for banned in ["apto", "plaza", "corte", "admit", "aprob", "suspens", "exclu"] {
            #expect(!texto.contains(banned), "«\(banned)» aparece en: \(texto)")
        }
    }
}

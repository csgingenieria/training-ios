import Testing
import Foundation

@testable import Dobacksoft_Training

/// What VoiceOver hears from a convocatoria's header card.
///
/// With `.combine`, SwiftUI concatenated the views in layout order and produced
/// «Oposición 2026, Abierta, 120, Aspirantes, Cierre punto medio 12/10/2026,
/// Actualizado punto medio 08/09/2026 13:42»: the figure before its label, and
/// the decorative separators read out as «punto medio».
struct ConvocatoriaHeaderCopyTests {
    private func label(
        name: String = "Oposición 2026",
        statusLabel: String? = "Abierta",
        totalCandidates: Int = 120,
        closedAt: String? = nil,
        updatedAt: String? = nil
    ) -> String {
        ConvocatoriaHeaderCopy.accessibilityLabel(
            name: name, statusLabel: statusLabel,
            totalCandidates: totalCandidates,
            closedAt: closedAt, updatedAt: updatedAt
        )
    }

    /// The figure comes WITH its unit, in the order it is understood.
    @Test func theFigureComesWithItsUnit() {
        #expect(label().contains("120 aspirantes"))
        #expect(!label().contains("120, Aspirantes"))
    }

    /// One is singular. «1 aspirantes» reads as a bug to the person listening.
    @Test func oneIsSingular() {
        #expect(label(totalCandidates: 1).contains("1 aspirante,") || label(totalCandidates: 1).hasSuffix("1 aspirante"))
        #expect(!label(totalCandidates: 1).contains("1 aspirantes"))
    }

    /// The dates are the LONG ones, because this is heard, not read.
    /// `shortDate` gives «12/10/2026», which VoiceOver says as «doce barra diez
    /// barra dos mil veintiséis».
    @Test func theDatesAreTheSpokenOnes() {
        let dicho = label(closedAt: "2026-10-12T00:00:00Z")
        #expect(dicho.contains("de octubre de 2026"))
        #expect(!dicho.contains("12/10/2026"))
    }

    /// «cerrada el» and not «cierre»: `closedAt` is when it closed, the same
    /// criterion the «Mi posición» subtitle already follows.
    @Test func theClosingDateIsInThePastTense() {
        #expect(label(closedAt: "2026-10-12T00:00:00Z").contains("cerrada el"))
    }

    /// What is absent is not named. A label ending in «cerrada el» with no date
    /// would be worse than saying nothing.
    @Test func whatIsAbsentIsNotNamed() {
        let dicho = label(statusLabel: nil, closedAt: nil, updatedAt: nil)
        #expect(dicho == "Oposición 2026, 120 aspirantes")
    }

    /// An unreadable timestamp behaves like a missing one.
    @Test func anUnreadableDateIsDropped() {
        #expect(!label(closedAt: "el martes").contains("cerrada"))
    }

    /// And nothing here carries a verdict.
    @Test func theHeaderStaysWithinArticle22() {
        let dicho = label(closedAt: "2026-10-12T00:00:00Z", updatedAt: "2026-09-08T13:42:00Z").lowercased()
        for banned in ["apto", "plaza", "corte", "admit", "aprob", "suspens", "exclu"] {
            #expect(!dicho.contains(banned), "«\(banned)» aparece en: \(dicho)")
        }
    }
}

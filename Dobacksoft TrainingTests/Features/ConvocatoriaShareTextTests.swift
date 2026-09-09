import Testing
import Foundation

@testable import Dobacksoft_Training

/// What leaves the app when a convocatoria is shared.
///
/// It was built inline in the detail view, and that is why it emitted the
/// backend's raw status: «Estado: OPEN». Same defect as the attempt's «Calidad:
/// HIGH», on another screen, unnoticed — the sign that copy assembled by hand
/// inside a view drifts on its own.
struct ConvocatoriaShareTextTests {
    private func convocatoria(
        status: String? = "OPEN", total: Int = 120, closedAt: String? = nil
    ) -> ConvocatoriaSummaryDTO {
        ConvocatoriaSummaryDTO(
            id: "c1", name: "Oposición 2026", description: nil, status: status,
            totalCandidates: total, closedAt: closedAt, updatedAt: nil
        )
    }

    /// **The label, not the code.** «OPEN» is a backend enum value and it was
    /// leaving the app in the one piece of copy that gets read elsewhere.
    @Test func theStatusIsTheLabelAndNotTheCode() {
        let texto = ConvocatoriaShareText.build(convocatoria())
        #expect(!texto.contains("OPEN"))
        #expect(texto.contains("Estado: \(StatusVocabulary.convocatoria("OPEN").label)"))
    }

    @Test func oneCandidateIsSingular() {
        #expect(ConvocatoriaShareText.build(convocatoria(total: 1)).contains("1 aspirante\n")
                || ConvocatoriaShareText.build(convocatoria(total: 1)).hasSuffix("1 aspirante"))
        #expect(!ConvocatoriaShareText.build(convocatoria(total: 1)).contains("1 aspirantes"))
    }

    /// The closing date in the past tense, which is what the field says.
    @Test func theClosingDateIsInThePastTense() {
        let texto = ConvocatoriaShareText.build(convocatoria(closedAt: "2026-10-12T00:00:00Z"))
        #expect(texto.contains("Cerrada el"))
        #expect(!texto.contains("Cierra"))
    }

    /// What is absent is not named: no «Estado:» with nothing after it.
    @Test func whatIsAbsentIsNotNamed() {
        let texto = ConvocatoriaShareText.build(convocatoria(status: nil))
        #expect(!texto.contains("Estado"))
    }

    /// The sentinel is not a status.
    @Test func theSentinelIsNotAStatus() {
        #expect(!ConvocatoriaShareText.build(convocatoria(status: "—")).contains("Estado"))
    }

    /// And what leaves the app never carries a verdict.
    @Test func whatLeavesTheAppStaysWithinArticle22() {
        let texto = ConvocatoriaShareText.build(
            convocatoria(closedAt: "2026-10-12T00:00:00Z")
        ).lowercased()
        for banned in ["apto", "plaza", "corte", "admit", "aprob", "suspens", "exclu"] {
            #expect(!texto.contains(banned), "«\(banned)» aparece en: \(texto)")
        }
    }
}

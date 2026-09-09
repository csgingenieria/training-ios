import Testing
import Foundation

@testable import Dobacksoft_Training

/// The shapes used for the loading skeleton.
///
/// They are covered by `.redacted(reason: .placeholder)` and hidden from
/// VoiceOver, so none of this is read or heard. It is written carefully anyway:
/// a filler figure that escaped to a screen would be an invented number about a
/// public examination, and this project does not invent data even in pretend.
struct PlaceholderShapesTests {
    /// **No filler figure claims anything.** A placeholder with «120
    /// aspirantes» inside would be a number nobody counted, one redaction bug
    /// away from being believed.
    @Test func theConvocatoriaPlaceholderClaimsNoFigures() {
        #expect(ConvocatoriaSummaryDTO.placeholder.totalCandidates == 0)
        #expect(ConvocatoriaSummaryDTO.placeholder.status == nil)
        #expect(ConvocatoriaSummaryDTO.placeholder.closedAt == nil)
    }

    /// And nothing in it reads as a verdict, in case it ever does reach a
    /// screen.
    @Test func thePlaceholderStaysWithinArticle22() {
        let texto = [
            ConvocatoriaSummaryDTO.placeholder.name,
            ConvocatoriaSummaryDTO.placeholder.description ?? ""
        ].joined(separator: " ").lowercased()

        for banned in ["apto", "plaza", "corte", "admit", "aprob", "suspens", "exclu"] {
            #expect(!texto.contains(banned), "«\(banned)» aparece en el relleno")
        }
    }

    /// It is recognisable as a placeholder and not as a real convocatoria: an
    /// id that could collide with a real one would let it into a navigation
    /// path.
    @Test func thePlaceholderCannotBeMistakenForRealData() {
        #expect(ConvocatoriaSummaryDTO.placeholder.id == "placeholder")
    }
}

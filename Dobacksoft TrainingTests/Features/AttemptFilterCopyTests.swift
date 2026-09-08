import Testing
import Foundation

@testable import Dobacksoft_Training

/// What VoiceOver hears from the «Filtros» menu of «Mis intentos».
///
/// The menu had a label —«Filtros de intentos»— and **said nothing about
/// whether any filter was on**. So someone using VoiceOver saw a shorter list
/// of laps with no way to learn it was filtered, and could reasonably conclude
/// they had driven fewer than they had. In an official examination that is not
/// a cosmetic gap.
///
/// Sighted users had a version of the same problem: the menu shows «Filtros»
/// whatever is selected.
struct AttemptFilterCopyTests {
    // MARK: - Sin filtros

    /// Nothing selected says so, plainly. Silence would be indistinguishable
    /// from a filter the reader cannot see.
    @Test func withNoFiltersItSaysSo() {
        #expect(AttemptFilterCopy.spokenState(quality: .all, score: .all) == "Sin filtros")
    }

    // MARK: - Con filtros

    @Test func oneFilterIsNamed() {
        #expect(AttemptFilterCopy.spokenState(quality: .high, score: .all) == "Filtrado por: Calidad alta")
        #expect(AttemptFilterCopy.spokenState(quality: .all, score: .unscored) == "Filtrado por: Sin nota")
    }

    /// Two filters are both named, in the order the menu lists them.
    @Test func twoFiltersAreBothNamed() {
        let dicho = AttemptFilterCopy.spokenState(quality: .low, score: .scored)
        #expect(dicho == "Filtrado por: Calidad baja, Con nota")
    }

    /// The word «filtrado» is what tells the person the list is not everything
    /// they have. It is the whole point of this sentence.
    @Test func theSentenceSaysTheListIsFiltered() {
        for (quality, score) in [
            (AttemptQualityFilter.high, AttemptScoreFilter.all),
            (.all, AttemptScoreFilter.scored),
            (.medium, .unscored)
        ] {
            #expect(
                AttemptFilterCopy.spokenState(quality: quality, score: score).contains("Filtrado"),
                "un filtro activo que no se anuncia como filtro no informa de nada"
            )
        }
    }

    /// And the control: with nothing filtered the word must NOT appear, or it
    /// would announce a filter on a complete list.
    @Test func withoutFiltersTheWordDoesNotAppear() {
        #expect(!AttemptFilterCopy.spokenState(quality: .all, score: .all).contains("Filtrado"))
    }

    // MARK: - El rótulo que se ve

    /// The visible label also changes, so a sighted person does not have to
    /// open the menu to find out whether the list is complete.
    @Test func theVisibleLabelSaysWhenSomethingIsFiltered() {
        #expect(AttemptFilterCopy.buttonLabel(quality: .all, score: .all) == "Filtros")
        #expect(AttemptFilterCopy.buttonLabel(quality: .high, score: .all) == "Filtros · 1")
        #expect(AttemptFilterCopy.buttonLabel(quality: .high, score: .scored) == "Filtros · 2")
    }

    /// No forbidden vocabulary reaches a filter name.
    @Test func filterNamesStayWithinArticle22() {
        for quality in AttemptQualityFilter.allCases {
            for score in AttemptScoreFilter.allCases {
                let dicho = AttemptFilterCopy.spokenState(quality: quality, score: score).lowercased()
                for banned in ["apto", "plaza", "corte", "admit", "aprob", "suspens", "exclu"] {
                    #expect(!dicho.contains(banned), "«\(banned)» aparece en: \(dicho)")
                }
            }
        }
    }
}

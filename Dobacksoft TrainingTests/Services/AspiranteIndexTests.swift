import Testing
import Foundation

@testable import Dobacksoft_Training

/// The instructor's index of enrolled candidates, derived from the ranking.
@MainActor
struct AspiranteIndexTests {
    private func aspirante(
        name: String = "Juan Pérez",
        plaza: String? = "42",
        haConducido: Bool = true
    ) -> ManagerPanelViewModel.Aspirante {
        .init(
            studentId: "s-1",
            name: name,
            plaza: plaza,
            convocatoriaName: "Convocatoria 2026",
            haConducido: haConducido
        )
    }

    @Test func matchesByNameIgnoringCase() {
        #expect(aspirante().matches("juan"))
        #expect(aspirante().matches("PÉREZ"))
    }

    @Test func matchesByPlaza() {
        #expect(aspirante().matches("42"))
    }

    @Test func doesNotMatchUnrelatedText() {
        #expect(!aspirante().matches("zzz"))
    }

    /// An empty query is not a filter: everyone stays.
    @Test func emptyQueryMatchesEveryone() {
        #expect(aspirante().matches(""))
        #expect(aspirante().matches("   "))
    }

    @Test func matchesWithoutPlaza() {
        #expect(aspirante(plaza: nil).matches("juan"))
        #expect(!aspirante(plaza: nil).matches("42"))
    }

    /// Two enrolments of the same person in different convocatorias are two
    /// rows, not one — otherwise SwiftUI collapses them in the list.
    @Test func identityIncludesTheConvocatoria() {
        let a = ManagerPanelViewModel.Aspirante(
            studentId: "s-1", name: "Juan", plaza: nil,
            convocatoriaName: "A", haConducido: false
        )
        let b = ManagerPanelViewModel.Aspirante(
            studentId: "s-1", name: "Juan", plaza: nil,
            convocatoriaName: "B", haConducido: false
        )
        #expect(a.id != b.id)
    }

    /// Spanish surnames carry accents and phone keyboards do not. Without
    /// folding, searching "Munoz" claimed nobody matched.
    @Test func searchIgnoresAccents() {
        let munoz = aspirante(name: "Juan Muñoz Núñez")
        #expect(munoz.matches("Munoz"))
        #expect(munoz.matches("nunez"))
        #expect(munoz.matches("MUÑOZ"))
    }

    /// A partial index must never be reported as a complete answer: saying
    /// "nobody matches" about people the app never looked up is a false
    /// statement, not a search result.
    @Test func partialCoverageAnnouncesItself() {
        var coverage = ManagerPanelViewModel.IndexCoverage(consultadas: 3, disponibles: 5)
        #expect(!coverage.esCompleta)
        #expect(coverage.aviso?.contains("3 de 5") == true)

        coverage = ManagerPanelViewModel.IndexCoverage(consultadas: 2, disponibles: 2)
        #expect(coverage.esCompleta)
        #expect(coverage.aviso == nil)
    }

    /// A failed read is not an empty convocatoria.
    @Test func failedReadsCountAsIncomplete() {
        let coverage = ManagerPanelViewModel.IndexCoverage(
            consultadas: 2, disponibles: 2, fallidas: 1
        )
        #expect(!coverage.esCompleta)
        #expect(coverage.aviso?.contains("1 de 2") == true)
    }

    @Test func totalFailureSaysSo() {
        let coverage = ManagerPanelViewModel.IndexCoverage(
            consultadas: 2, disponibles: 2, fallidas: 2
        )
        #expect(coverage.aviso?.contains("No se ha podido") == true)
    }

    /// `pendientes` is derived, so it can never drift from the index.
    @Test func pendientesAreTheOnesWhoHaveNotDriven() {
        let viewModel = ManagerPanelViewModel()
        viewModel.aspirantes = [
            aspirante(name: "Condujo", haConducido: true),
            .init(studentId: "s-2", name: "No condujo", plaza: "7",
                  convocatoriaName: "Convocatoria 2026", haConducido: false),
        ]
        #expect(viewModel.pendientes.count == 1)
        #expect(viewModel.pendientes.first?.name == "No condujo")
    }
}

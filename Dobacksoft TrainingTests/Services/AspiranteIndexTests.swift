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

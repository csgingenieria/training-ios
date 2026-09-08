import Testing
import Foundation

@testable import Dobacksoft_Training

/// The subtitle under «Hola, <nombre>» on «Mi posición».
///
/// It used to be a count — «1 convocatoria activa» — which in the common case
/// (one convocatoria, no chip row, because chips only appear from two) told
/// the candidate nothing they could not already see. The web hero always
/// prints the name and the closing date instead.
///
/// And the count was wrong twice over: it counted every enrolment, closed ones
/// included, while calling them «activas».
struct StandingHeaderCopyTests {
    private func convocatoria(
        id: String = "c1",
        name: String = "Oposición 2026",
        status: String? = "OPEN",
        closedAt: String? = nil
    ) -> ConvocatoriaSummaryDTO {
        ConvocatoriaSummaryDTO(
            id: id,
            name: name,
            description: nil,
            status: status,
            totalCandidates: 0,
            closedAt: closedAt,
            updatedAt: nil
        )
    }

    // MARK: - Lo que dice el subtítulo

    @Test func withOneConvocatoriaItIsNamed() {
        let subtitulo = StandingHeaderCopy.subtitle(
            selected: convocatoria(),
            convocatorias: [convocatoria()]
        )
        #expect(subtitulo == "Oposición 2026")
    }

    /// The closing date is appended only when there is one, and only in the
    /// past tense the field actually carries: `closedAt` is when it CLOSED, so
    /// «Cerrada el» — never «Cierra el», which would promise a deadline the
    /// contract does not send.
    @Test func aClosedConvocatoriaSaysWhenItClosed() throws {
        let cerrada = convocatoria(status: "CLOSED", closedAt: "2026-10-12T00:00:00Z")
        let subtitulo = StandingHeaderCopy.subtitle(selected: cerrada, convocatorias: [cerrada])

        let fecha = try #require(APIDate.shortDate("2026-10-12T00:00:00Z"))
        #expect(subtitulo == "Oposición 2026 · Cerrada el \(fecha)")
        #expect(!subtitulo.contains("Cierra"), "una fecha pasada no es un plazo")
    }

    /// An unreadable timestamp behaves like a missing one: the name alone,
    /// never a label with nothing after it.
    @Test func anUnreadableClosingDateIsDropped() {
        let raro = convocatoria(status: "CLOSED", closedAt: "el martes")
        let subtitulo = StandingHeaderCopy.subtitle(selected: raro, convocatorias: [raro])
        #expect(subtitulo == "Oposición 2026")
    }

    /// A blank name is not a name. The count is the honest fallback.
    @Test func aBlankNameFallsBackToTheCount() {
        let sinNombre = convocatoria(name: "   ")
        #expect(StandingHeaderCopy.subtitle(
            selected: sinNombre,
            convocatorias: [sinNombre]
        ) == "1 convocatoria en curso")
    }

    // MARK: - La cuenta, cuando hay cuenta

    /// With nothing selected yet the subtitle counts — and counts only the
    /// ones in course, which is what it claims to be counting.
    @Test func theCountOnlyCountsTheOnesInCourse() {
        let convocatorias = [
            convocatoria(id: "a", status: "OPEN"),
            convocatoria(id: "b", status: "CLOSED"),
            convocatoria(id: "c", status: "LOCKED"),
            convocatoria(id: "d", status: "PREVIEW")
        ]
        #expect(StandingHeaderCopy.subtitle(
            selected: nil,
            convocatorias: convocatorias
        ) == "2 convocatorias en curso")
    }

    @Test func noneInCourseSaysSo() {
        let cerradas = [convocatoria(id: "a", status: "CLOSED")]
        #expect(StandingHeaderCopy.subtitle(
            selected: nil,
            convocatorias: cerradas
        ) == "Sin convocatorias en curso")
    }

    @Test func noEnrolmentsAtAllSaysSo() {
        #expect(StandingHeaderCopy.subtitle(selected: nil, convocatorias: []) == "Sin convocatorias en curso")
    }

    /// The singular is a singular. «1 convocatorias» reads as a bug to the
    /// person the app is for.
    @Test func oneIsSingular() {
        let una = [convocatoria(id: "a", status: "OPEN"), convocatoria(id: "b", status: "CLOSED")]
        #expect(StandingHeaderCopy.subtitle(selected: nil, convocatorias: una) == "1 convocatoria en curso")
    }

    /// «en curso» and not «activa»: it is the word the convocatoria filter
    /// already shows on the list screen, and two words for one state is how a
    /// candidate ends up wondering whether they are different things.
    ///
    /// The expected word is written out here on purpose. Asserting it with
    /// `ConvocatoriaScope.activas.title` — which is what the implementation
    /// reads — would pass no matter what either of them said.
    @Test func theWordIsTheOneTheFilterShows() {
        let subtitulo = StandingHeaderCopy.subtitle(
            selected: nil,
            convocatorias: [convocatoria(status: "OPEN")]
        )
        #expect(subtitulo.contains("en curso"))
        #expect(!subtitulo.contains("activa"))
        #expect(ConvocatoriaScope.activas.title == "En curso",
                "si el filtro cambia de palabra, este subtítulo tiene que cambiar con él")
    }

    /// And it never carries a verdict.
    @Test func theSubtitleStaysWithinArticle22() {
        let cerrada = convocatoria(status: "CLOSED", closedAt: "2026-10-12T00:00:00Z")
        let textos = [
            StandingHeaderCopy.subtitle(selected: cerrada, convocatorias: [cerrada]),
            StandingHeaderCopy.subtitle(selected: nil, convocatorias: [cerrada])
        ]
        for texto in textos.map({ $0.lowercased() }) {
            for banned in ["apto", "plaza", "corte", "admit", "aprob", "suspens", "exclu"] {
                #expect(!texto.contains(banned), "«\(banned)» aparece en: \(texto)")
            }
        }
    }
}

import Testing
import Foundation

@testable import Dobacksoft_Training

/// Ordenar y filtrar la lista de vueltas del aspirante.
///
/// La lógica vivía en tipos propios —`AttemptSortMode`, `AttemptQualityFilter`,
/// `AttemptScoreFilter`— pero solo se probaban sus **textos**, no lo que hacen.
/// Y hay una decisión de producto escondida en el orden por nota que ninguna
/// prueba sujetaba: **una vuelta sin nota va al final en los dos sentidos**.
///
/// Está resuelta con dos centinelas distintos —`-1` al descender e `infinity`
/// al ascender— y es correcta, pero es exactamente el tipo de truco que alguien
/// «simplifica» meses después dejando las vueltas sin nota arriba del todo en
/// «Peor nota», donde parecen las peores. No lo son: son las que aún no se han
/// evaluado, y confundirlas es justo lo que este proyecto no hace.
@MainActor
struct AttemptSortAndFilterTests {
    private func vuelta(
        _ id: String,
        nota: Double? = nil,
        fecha: String? = nil,
        calidad: String? = nil
    ) -> AttemptSummaryDTO {
        AttemptSummaryDTO(id: id, score: nota, dataQuality: calidad, createdAt: fecha)
    }

    // MARK: - El orden

    @Test func masRecientesPrimeroOrdenaPorFechaDescendente() {
        let items = [
            vuelta("a", fecha: "2026-09-01T10:00:00Z"),
            vuelta("c", fecha: "2026-09-03T10:00:00Z"),
            vuelta("b", fecha: "2026-09-02T10:00:00Z")
        ]
        #expect(AttemptSortMode.newestFirst.apply(items).map(\.id) == ["c", "b", "a"])
        #expect(AttemptSortMode.oldestFirst.apply(items).map(\.id) == ["a", "b", "c"])
    }

    @Test func mejorNotaPrimeroOrdenaPorNotaDescendente() {
        let items = [vuelta("a", nota: 5), vuelta("c", nota: 9), vuelta("b", nota: 7)]
        #expect(AttemptSortMode.scoreDescending.apply(items).map(\.id) == ["c", "b", "a"])
        #expect(AttemptSortMode.scoreAscending.apply(items).map(\.id) == ["a", "b", "c"])
    }

    /// **La decisión que había que sujetar.** Sin nota no es «nota cero»: es una
    /// vuelta que todavía no se ha evaluado, y ponerla la primera en «Peor nota»
    /// la presentaría como la peor de todas.
    @Test func lasVueltasSinNotaVanAlFinalEnLosDosSentidos() {
        let items = [
            vuelta("sinNota"),
            vuelta("alta", nota: 9),
            vuelta("baja", nota: 3)
        ]
        #expect(AttemptSortMode.scoreDescending.apply(items).map(\.id) == ["alta", "baja", "sinNota"])
        #expect(AttemptSortMode.scoreAscending.apply(items).map(\.id) == ["baja", "alta", "sinNota"])
    }

    /// Y con un cero de verdad: el cero es una nota, y va donde le toca por
    /// valor — antes que las que no tienen nota.
    @Test func unCeroEsUnaNotaYNoSeConfundeConNoTenerla() {
        let items = [vuelta("sinNota"), vuelta("cero", nota: 0), vuelta("siete", nota: 7)]
        #expect(AttemptSortMode.scoreAscending.apply(items).map(\.id) == ["cero", "siete", "sinNota"])
        #expect(AttemptSortMode.scoreDescending.apply(items).map(\.id) == ["siete", "cero", "sinNota"])
    }

    // MARK: - El filtro de calidad

    /// El backend nombra la misma calidad de dos maneras, y el filtro acepta
    /// ambas: si solo entendiera una, media lista desaparecería sin decir nada.
    @Test func elFiltroDeCalidadEntiendeLosDosVocabularios() {
        #expect(AttemptQualityFilter.high.matches(vuelta("x", calidad: "HIGH")))
        #expect(AttemptQualityFilter.high.matches(vuelta("x", calidad: "GOOD")))
        #expect(AttemptQualityFilter.medium.matches(vuelta("x", calidad: "MEDIUM")))
        #expect(AttemptQualityFilter.medium.matches(vuelta("x", calidad: "OK")))
        #expect(AttemptQualityFilter.low.matches(vuelta("x", calidad: "LOW")))
        #expect(AttemptQualityFilter.low.matches(vuelta("x", calidad: "BAD")))
    }

    @Test func elFiltroDeCalidadIgnoraLasMayusculas() {
        #expect(AttemptQualityFilter.high.matches(vuelta("x", calidad: "high")))
        #expect(AttemptQualityFilter.low.matches(vuelta("x", calidad: "bad")))
    }

    /// «Todas» incluye lo que no declara calidad. Una vuelta sin ese dato no
    /// puede desaparecer del listado por un filtro que dice no filtrar.
    @Test func todasLasCalidadesIncluyeLaQueNoLaDeclara() {
        #expect(AttemptQualityFilter.all.matches(vuelta("x", calidad: nil)))
        #expect(AttemptQualityFilter.all.matches(vuelta("x", calidad: "CUALQUIERA")))
    }

    /// Y el control: un filtro concreto **sí** excluye. Sin esto, la prueba de
    /// arriba se contentaría con un filtro que no filtra nunca.
    @Test func unFiltroConcretoSiExcluye() {
        #expect(!AttemptQualityFilter.high.matches(vuelta("x", calidad: "LOW")))
        #expect(!AttemptQualityFilter.low.matches(vuelta("x", calidad: nil)))
    }

    // MARK: - El filtro de nota

    @Test func elFiltroDeNotaSeparaLoEvaluadoDeLoPendiente() {
        let conNota = vuelta("a", nota: 6)
        let sinNota = vuelta("b")

        #expect(AttemptScoreFilter.scored.matches(conNota))
        #expect(!AttemptScoreFilter.scored.matches(sinNota))
        #expect(AttemptScoreFilter.unscored.matches(sinNota))
        #expect(!AttemptScoreFilter.unscored.matches(conNota))
        #expect(AttemptScoreFilter.all.matches(conNota))
        #expect(AttemptScoreFilter.all.matches(sinNota))
    }

    /// Un cero cuenta como evaluado: es una nota, no una ausencia.
    @Test func unCeroCuentaComoEvaluado() {
        #expect(AttemptScoreFilter.scored.matches(vuelta("x", nota: 0)))
        #expect(!AttemptScoreFilter.unscored.matches(vuelta("x", nota: 0)))
    }

    // MARK: - Los textos no pronuncian un veredicto

    /// Artículo 22: ni el orden ni los filtros pueden nombrar un resultado.
    /// «Mejor nota» ordena; «aprobado» juzgaría.
    @Test func ningunTituloUsaVocabularioProhibido() {
        let prohibidas = ["apto", "aprobad", "suspens", "admitid", "excluid", "corte", "plaza", "cupo"]
        let titulos = AttemptSortMode.allCases.map(\.title)
            + AttemptQualityFilter.allCases.map(\.title)
            + AttemptScoreFilter.allCases.map(\.title)

        for titulo in titulos {
            let plano = titulo.lowercased()
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_ES"))
            for prohibida in prohibidas {
                #expect(!plano.contains(prohibida), "«\(titulo)» contiene «\(prohibida)»")
            }
        }
    }
}

import Testing
import Foundation
import SwiftUI

@testable import Dobacksoft_Training

/// How wide the instructor's results table columns are.
///
/// They were three fixed values — 34, 150 and 62 pt — with `lineLimit(1)`, so a
/// three-digit position and any long name clipped at large text sizes, and on
/// an iPad the table left a blank strip on the right because `proxy.size.width`
/// was never read. Instructor-only, which is why it waited behind every
/// candidate-facing item.
struct ResultadosColumnsTests {
    private let fixed = ResultadosColumns.Widths(position: 34, score: 62, circuit: 62)

    // MARK: - La columna del nombre crece con el sitio que hay

    /// On an iPad pane the leftover space goes to the name, which is the only
    /// column whose content has no fixed length.
    @Test func theNameTakesTheLeftoverSpace() {
        let width = ResultadosColumns.nameWidth(available: 1000, circuits: 5, widths: fixed)
        // 1000 − 34 − 62 − 5×62 = 594
        #expect(width == 594)
    }

    /// A narrow container never squeezes the name below its floor: a name
    /// column of 40 pt is not a table, it is a column of ellipses. The table
    /// scrolls horizontally instead, which it already did.
    @Test func aNarrowContainerFallsBackToTheFloor() {
        #expect(ResultadosColumns.nameWidth(available: 400, circuits: 5, widths: fixed) == ResultadosColumns.minimumNameWidth)
        #expect(ResultadosColumns.nameWidth(available: 0, circuits: 5, widths: fixed) == ResultadosColumns.minimumNameWidth)
    }

    /// The floor is the old fixed width, so nothing gets narrower than it is
    /// today. This is a widening change, never a narrowing one.
    @Test func theFloorIsTheWidthItUsedToHave() {
        #expect(ResultadosColumns.minimumNameWidth == 150)
    }

    /// Every circuit subtracts. A convocatoria with many circuits fills the
    /// pane on its own and the name stays at the floor.
    @Test func eachCircuitTakesItsShare() {
        let five = ResultadosColumns.nameWidth(available: 1000, circuits: 5, widths: fixed)
        let six = ResultadosColumns.nameWidth(available: 1000, circuits: 6, widths: fixed)
        #expect(five - six == fixed.circuit)
    }

    /// No circuits at all is a real state — a convocatoria with nothing set up
    /// yet — and the name simply takes everything left.
    @Test func withNoCircuitsTheNameTakesEverything() {
        // El esperado se escribe con los propios campos y no con literales:
        // con `500 - 34 - 62` la aserción fallaba comparando 404,0 contra 404,
        // que es una discrepancia de TIPOS, no de valor. Una aserción cuyos
        // tipos no sé explicar no es una aserción que deba quedarse.
        let esperado: CGFloat = 500 - fixed.position - fixed.score
        #expect(ResultadosColumns.nameWidth(available: 500, circuits: 0, widths: fixed) == esperado)
    }

    /// A negative or absurd container cannot produce a negative width. SwiftUI
    /// crashes on a negative frame.
    @Test func anAbsurdContainerNeverYieldsANegativeWidth() {
        #expect(ResultadosColumns.nameWidth(available: -1000, circuits: 3, widths: fixed) > 0)
        #expect(ResultadosColumns.nameWidth(available: 1000, circuits: 1000, widths: fixed) > 0)
    }

    // MARK: - Las columnas escalan con el tamaño de letra

    /// The control case for the whole change: the widths must actually MOVE
    /// with the text size. If they did not, `@ScaledMetric` would be
    /// decoration and every test above would still pass.
    @Test func theWidthsGrowWithTheTextSize() {
        let normal = ResultadosColumns.Widths(position: 34, score: 62, circuit: 62)
        let large = ResultadosColumns.Widths(position: 51, score: 93, circuit: 93)

        let atNormal = ResultadosColumns.nameWidth(available: 1000, circuits: 3, widths: normal)
        let atLarge = ResultadosColumns.nameWidth(available: 1000, circuits: 3, widths: large)

        #expect(atLarge < atNormal, "columnas más anchas dejan menos sitio al nombre")
    }

    // MARK: - Cuántas líneas para el nombre

    /// At accessibility text sizes a name gets two lines instead of being
    /// truncated. A clipped surname in an official ranking is a person the
    /// instructor cannot identify.
    @Test func accessibilitySizesGetASecondLine() {
        #expect(ResultadosColumns.nameLineLimit(for: .accessibility1) == 2)
        #expect(ResultadosColumns.nameLineLimit(for: .accessibility5) == 2)
    }

    /// And ordinary sizes keep one line, so the rows stay aligned with the
    /// header. Without this half the test above would pass for a table that is
    /// always two lines tall.
    @Test func ordinarySizesKeepOneLine() {
        #expect(ResultadosColumns.nameLineLimit(for: .large) == 1)
        #expect(ResultadosColumns.nameLineLimit(for: .xxxLarge) == 1)
    }
}

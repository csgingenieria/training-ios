import SwiftUI

/// El ancho de las columnas de la tabla de resultados del instructor.
///
/// Eran tres valores fijos —34, 150 y 62 pt— con `lineLimit(1)`, así que una
/// posición de tres cifras y cualquier apellido largo se cortaban con la letra
/// grande, y en un iPad la tabla dejaba una franja en blanco a la derecha
/// porque nadie leía el ancho del contenedor.
///
/// Vive fuera de la vista porque «cuánto sitio le queda al nombre» es una resta
/// con un suelo, y una resta con un suelo es donde alguien pone un `max` al
/// revés y nadie lo nota hasta que un iPad estrecho pinta cuarenta puntos de
/// puntos suspensivos.
nonisolated enum ResultadosColumns {
    /// El nombre no baja de aquí.
    ///
    /// Es el ancho fijo que tenía, así que este cambio solo puede ensanchar.
    /// Por debajo la tabla scrollea en horizontal, que es lo que ya hacía.
    static let minimumNameWidth: CGFloat = 150

    /// Los anchos de las columnas de contenido acotado, ya escalados.
    struct Widths: Hashable, Sendable {
        let position: CGFloat
        let score: CGFloat
        let circuit: CGFloat

        /// El relleno horizontal de la celda del nombre, que va POR FUERA de
        /// su `frame` y por tanto también ocupa. Sin contarlo, la fila mide
        /// más que el contenedor y vuelve la franja en blanco por el otro
        /// lado: un scroll horizontal de dos puntos.
        let namePadding: CGFloat

        init(position: CGFloat, score: CGFloat, circuit: CGFloat, namePadding: CGFloat = 0) {
            self.position = position
            self.score = score
            self.circuit = circuit
            self.namePadding = namePadding
        }
    }

    /// Lo que le queda al nombre después de las demás columnas.
    static func nameWidth(available: CGFloat, circuits: Int, widths: Widths) -> CGFloat {
        // Un número de circuitos negativo no existe, pero restar por él daría
        // un nombre más ancho que la pantalla.
        let circuitos = CGFloat(max(0, circuits))
        let ocupado = widths.position + widths.score
            + circuitos * widths.circuit
            + 2 * widths.namePadding
        // `max` con el suelo, y nunca un negativo: SwiftUI se cae con un
        // `frame` de ancho negativo.
        return max(minimumNameWidth, available - ocupado)
    }

    /// Cuántas líneas para el nombre.
    ///
    /// Dos con los tamaños de accesibilidad: un apellido cortado en un ranking
    /// oficial es una persona que el instructor no puede identificar. Una en
    /// los tamaños normales, para que las filas sigan alineadas con la
    /// cabecera.
    static func nameLineLimit(for size: DynamicTypeSize) -> Int {
        size.isAccessibilitySize ? 2 : 1
    }
}

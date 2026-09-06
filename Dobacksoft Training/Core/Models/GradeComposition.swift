import Foundation

/// De qué está hecha la nota oficial de un aspirante.
///
/// Sin esto, la app pintaba «4,75» y punto. Ese número puede ser la media de
/// cinco recorridos conducidos entre 8,5 y 10 **más cinco ceros** por
/// recorridos que el aspirante todavía no ha hecho —o que el tribunal nunca
/// hizo conducibles—. Alguien que lee 4,75 a secas concluye que conduce mal, y
/// es la pantalla desde la que se decide si se recurre.
///
/// La fórmula es: suma del mejor intento de cada recorrido exigido conducido,
/// dividida entre el **número total de recorridos exigidos**. El denominador es
/// fijo: lo exigido y no conducido cuenta cero.
struct GradeComposition: Sendable, Equatable {
    /// Recorridos que la convocatoria exige.
    ///
    /// `nil` significa que **no exige ninguno** y la nota es el mejor intento
    /// global (el backend lo llama régimen H7). No confundir con lista vacía:
    /// eso diría que exige cero, que es otra cosa.
    let requiredRoutes: [String]?

    let completedRequired: Int
    let pendingRequired: Int

    /// Media de lo que sí ha conducido, sin los ceros.
    ///
    /// `nil` en tres casos legítimos: sin recorridos exigidos, sin nada
    /// conducido, o con todo conducido (ahí coincide con la nota oficial y
    /// repetirla sería ruido).
    let scoreOfCompleted: Double?

    /// `true` cuando la convocatoria no exige recorridos concretos.
    var isGlobalBest: Bool { requiredRoutes == nil }

    var totalRequired: Int { requiredRoutes?.count ?? 0 }

    /// `true` cuando quedan recorridos exigidos por conducir, y por tanto la
    /// nota oficial incluye ceros que no describen cómo conduce el aspirante.
    var hasPendingRoutes: Bool { pendingRequired > 0 }

    /// Explicación de una línea, o `nil` si no hay nada que explicar.
    ///
    /// Deliberadamente descriptiva: dice qué compone el número, no qué debería
    /// hacer el aspirante. «Le faltan recorridos» insinúa un deber y un
    /// resultado; «incluye N recorridos aún sin conducir» es un hecho.
    var explanation: String? {
        guard !isGlobalBest, hasPendingRoutes else { return nil }
        let plural = pendingRequired == 1
            ? "1 recorrido aún sin conducir"
            : "\(pendingRequired) recorridos aún sin conducir"
        return "Incluye \(plural), que computan como cero."
    }

    /// Progreso sobre los recorridos exigidos, para una barra.
    /// `nil` cuando no hay conjunto exigido y por tanto no hay progreso que medir.
    var progress: Double? {
        guard !isGlobalBest, totalRequired > 0 else { return nil }
        return Double(completedRequired) / Double(totalRequired)
    }
}

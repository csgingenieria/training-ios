import Foundation

/// Qué recorridos exigidos le faltan al aspirante por conducir.
///
/// Es la pregunta que la nota oficial convierte en dinero: la nota es la media
/// del mejor intento por recorrido EXIGIDO, **contando 0 los que no se han
/// conducido** (#845). Quien no sabe cuáles le faltan no puede actuar sobre lo
/// único que más le movería la nota.
///
/// El cliente deriva los NOMBRES por resta de conjuntos. **No deriva la nota**,
/// y tampoco la cuenta: la manda el backend en `pendingRequired`. La derivación
/// se contrasta contra esa cuenta y, cuando no coinciden, los nombres se
/// callan: mandar a alguien a conducir un recorrido que ya condujo es peor que
/// no decirle nada.
nonisolated enum RequiredRoutes {
    /// Los exigidos que no constan conducidos, o `nil` si no se puede afirmar.
    ///
    /// `nil` no es «ninguno»: es «no lo sé». La pantalla tiene que distinguir
    /// las dos cosas, porque una lista vacía dice «lo tiene todo hecho».
    static func pending(in progress: ProgressDTO) -> [String]? {
        let required = (progress.requiredRoutes ?? []).compactMap(normalise)
        // Sin recorridos exigidos el concepto no existe: la nota es el mejor
        // intento global y no hay nada pendiente que nombrar.
        guard !required.isEmpty else { return nil }

        let driven = Set(progress.evolution.compactMap { normalise($0.routeCode) })

        // El orden es el de la convocatoria, no el alfabético: es el orden en
        // el que el aspirante los ve en todas las demás pantallas.
        let pending = (progress.requiredRoutes ?? []).filter { code in
            guard let normalised = normalise(code) else { return false }
            return !driven.contains(normalised)
        }

        // La comprobación de acuerdo. Sin la cuenta del backend no hay contra
        // qué contrastar, así que no se afirma nada.
        guard let expected = progress.pendingRequired else { return nil }
        guard pending.count == expected else { return nil }

        return pending
    }

    /// Códigos comparables: recortados y en una sola caja.
    ///
    /// Una diferencia de espacios o de mayúsculas no puede mandar a alguien a
    /// conducir un recorrido que ya condujo.
    private static func normalise(_ code: String?) -> String? {
        guard let code else { return nil }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.uppercased()
    }

    /// La frase, o `nil` si no hay nada que decir.
    ///
    /// Nombra lo que cuesta el cero, porque es la razón para hacer algo. No
    /// regaña y no predice ningún resultado.
    static func notice(for pending: [String]) -> String? {
        guard !pending.isEmpty else { return nil }
        let lista = pending.joined(separator: ", ")
        return pending.count == 1
            ? "El recorrido \(lista) no consta conducido. La nota oficial lo cuenta como 0 hasta que lo conduzca."
            : "Los recorridos \(lista) no constan conducidos. La nota oficial los cuenta como 0 hasta que los conduzca."
    }
}

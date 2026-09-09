import Foundation

/// Los dos datos que el portal saca de los intentos y la app no sacaba.
///
/// La tarjeta enseñaba la nota y el número de intentos, y ya los tenía todos en
/// la mano: la fecha del último intento y en qué recorrido va mejor y peor
/// salen de la MISMA lista que ya está cargada. Ni una petición más.
nonisolated enum AttemptHighlights {
    /// Cuándo fue la última vuelta.
    ///
    /// El máximo por INSTANTE, no el primero de la lista: la lista viene
    /// ordenada por fecha, pero eso es una propiedad del backend que puede
    /// cambiar sin avisar, y ordenar aquí cuesta nada.
    static func lastAttemptDate(_ attempts: [AttemptSummaryDTO]) -> String? {
        attempts
            .compactMap { $0.createdAt }
            .compactMap { fecha in APIDate.parse(fecha).map { ($0, fecha) } }
            .max(by: { $0.0 < $1.0 })?
            .1
    }

    /// El mejor y el peor recorrido, **solo si son distintos**.
    ///
    /// Con un recorrido calificado los dos son el mismo, y decir «mejor: 2B3 ·
    /// a mejorar: 2B3» no informa de nada — es la misma regla que ya sigue la
    /// tarjeta de extremos de «Mi progreso».
    ///
    /// Las prácticas quedan fuera: no cuentan para la nota, y señalar como «a
    /// mejorar» un recorrido que no puntúa manda a alguien a trabajar donde no
    /// le sirve.
    static func bestAndWorst(
        _ attempts: [AttemptSummaryDTO]
    ) -> (best: (code: String, score: Double), worst: (code: String, score: Double))? {
        var mejorPorRecorrido: [String: Double] = [:]
        for intento in attempts where intento.route?.isPractice != true {
            guard let codigo = intento.route?.displayName,
                  let nota = intento.score else { continue }
            mejorPorRecorrido[codigo] = max(mejorPorRecorrido[codigo] ?? nota, nota)
        }

        guard mejorPorRecorrido.count > 1,
              let mejor = mejorPorRecorrido.max(by: { $0.value < $1.value }),
              let peor = mejorPorRecorrido.min(by: { $0.value < $1.value }),
              mejor.key != peor.key
        else { return nil }

        return ((mejor.key, mejor.value), (peor.key, peor.value))
    }
}

import Foundation

/// Lo que dice el menú de filtros de «Mis intentos».
///
/// Tenía etiqueta —«Filtros de intentos»— y **no decía si había algún filtro
/// puesto**. Así que quien usa VoiceOver veía una lista más corta de vueltas
/// sin manera de enterarse de que estaba filtrada, y podía concluir
/// razonablemente que había conducido menos de las que condujo. En una
/// oposición eso no es un detalle cosmético.
///
/// Y quien ve la pantalla tenía una versión del mismo problema: el menú pone
/// «Filtros» pase lo que pase.
nonisolated enum AttemptFilterCopy {
    /// Los filtros activos, nombrados. `«Sin filtros»` cuando no hay ninguno.
    ///
    /// La palabra «Filtrado» es lo que le dice a la persona que la lista no es
    /// todo lo que tiene; sin ella, nombrar los filtros no informa de nada.
    static func spokenState(quality: AttemptQualityFilter, score: AttemptScoreFilter) -> String {
        let activos = activeTitles(quality: quality, score: score)
        guard !activos.isEmpty else { return "Sin filtros" }
        return "Filtrado por: \(activos.joined(separator: ", "))"
    }

    /// El rótulo visible, con la cuenta cuando hay filtros.
    ///
    /// Para no tener que abrir el menú para saber si la lista está completa.
    static func buttonLabel(quality: AttemptQualityFilter, score: AttemptScoreFilter) -> String {
        let activos = activeTitles(quality: quality, score: score)
        return activos.isEmpty ? "Filtros" : "Filtros · \(activos.count)"
    }

    /// En el orden en que el menú los lista, no en otro: quien lo abre después
    /// de oírlo tiene que encontrarlos donde se los han dicho.
    private static func activeTitles(
        quality: AttemptQualityFilter,
        score: AttemptScoreFilter
    ) -> [String] {
        var titulos: [String] = []
        if quality != .all { titulos.append(quality.title) }
        if score != .all { titulos.append(score.title) }
        return titulos
    }
}

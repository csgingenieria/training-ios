import Foundation

/// Una fila de «Resultados»: un aspirante, su nota agregada y su nota en cada
/// recorrido.
///
/// El portal web resuelve esto en una sola tabla (`mgr-matrix--ranked` en
/// `manager/resultados.html`) y la app lo tenía partido en dos pantallas:
/// «Ranking completo» y «Matriz de puntuaciones». Separadas, ninguna de las dos
/// contesta lo que un instructor pregunta de verdad. El ranking dice quién va
/// delante pero no de qué está hecha la nota; la matriz dice qué ha conducido
/// cada uno pero no en qué orden quedan.
struct ResultadoRow: Identifiable, Sendable {
    let candidateId: String
    let name: String
    let plaza: String?

    /// Puesto en el orden de méritos, o `nil` para quien no ha conducido.
    let position: Int?

    /// `true` si comparte puesto con alguien. El backend usa numeración de
    /// competición (1, 2, 2, 4) y sin decirlo dos filas iguales parecen un
    /// fallo de la app.
    let tied: Bool

    /// Nota oficial mostrable, o `nil` si no hay ninguna que mostrar.
    let score: Double?

    /// De qué está hecha esa nota, cuando el contrato lo envía.
    let composition: GradeComposition?

    /// Nota por recorrido, indexada por identificador de circuito.
    let byCircuit: [String: MatrixScoreDTO]

    var id: String { candidateId }

    /// `true` cuando la persona está inscrita y no ha conducido nada.
    var hasNotDriven: Bool { position == nil }
}

/// Todo lo que «Resultados» necesita, ya cruzado.
struct ResultadosData: Sendable {
    let convocatoriaName: String
    let convocatoriaStatus: String?

    /// Columnas de la tabla, en orden.
    let circuits: [MatrixCircuitDTO]

    /// Quien ha conducido, en orden de méritos.
    let ranked: [ResultadoRow]

    /// Inscritos sin ningún recorrido calificado.
    ///
    /// En sección aparte, como en el portal: mezclarlos con los demás los
    /// pondría en un orden de méritos del que no forman parte.
    let notPresented: [ResultadoRow]

    var totalCandidates: Int { ranked.count + notPresented.count }

    /// Recorridos reales de la tabla, sin la columna sintética.
    var realCircuitCount: Int { circuits.filter { !$0.isSynthetic }.count }

    /// `true` cuando alguna columna EXIGIDA no tiene ninguna nota.
    ///
    /// Se apoya en `required` de la propia columna en vez de deducirlo: hay un
    /// caso conocido en el backend en el que una ruta de PRÁCTICAS puede
    /// acabar en el conjunto exigido (`_rutas_exigidas_validas` no comprueba
    /// `Route.categoria`) y su columna sale vacía incluso para quien la
    /// condujo. Con `required` la app dice «no consta conducida», que es
    /// verdad sobre el dato, en vez de «nadie la ha conducido», que sería una
    /// afirmación sobre la realidad que no puede sostener.
    var hasUndrivenRequiredColumn: Bool {
        circuits.contains { circuit in
            circuit.isRequired
                && !circuit.isSynthetic
                && !ranked.contains { $0.byCircuit[circuit.id]?.score != nil }
        }
    }
}

// MARK: - Cruce

extension ResultadosData {
    /// Cruza ranking y matriz en una sola tabla.
    ///
    /// **Las columnas son las que manda la matriz, y punto.** Durante un rato
    /// este cliente las derivaba cruzando `requiredRoutes` del ranking, porque
    /// la matriz solo devolvía circuitos con algún intento —cinco de los diez
    /// exigidos— y ocultaba justo las columnas que explican cada nota. El
    /// defecto estaba en `get_matrix_data` y se arregló allí: ahora devuelve
    /// los diez, con `required` en cada columna y el nombre real del recorrido.
    ///
    /// Derivarlo aquí ya sería duplicar una lógica que el backend resuelve con
    /// el mismo saneador canónico que usa el ranking, que es lo que garantiza
    /// que las dos mitades de esta pantalla no puedan divergir.
    static func merge(
        ranking: RankingResponseDTO,
        matrix: MatrixResponseDTO?
    ) -> ResultadosData {
        let matrixRows = Dictionary(
            (matrix?.rows ?? []).map { ($0.candidate.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var rows: [ResultadoRow] = ranking.entries.map { entry in
            let candidateId = entry.candidate.id ?? ""
            let scores = matrixRows[candidateId]?.scores ?? []
            return ResultadoRow(
                candidateId: candidateId.isEmpty ? "anon-\(entry.id)" : candidateId,
                name: entry.candidate.name ?? "—",
                plaza: entry.candidate.plaza,
                position: entry.hasNotDriven ? nil : entry.position,
                tied: entry.tied == true,
                score: entry.displayScore,
                composition: entry.composition,
                byCircuit: Dictionary(
                    scores.map { ($0.circuitId, $0) },
                    uniquingKeysWith: { first, _ in first }
                )
            )
        }

        // Alguien puede estar en la matriz y no en el ranking. Un test de
        // integración del portal existe justo para vigilar que las dos fuentes
        // traigan la misma gente, así que si divergen no se puede perder a
        // nadie por el camino.
        let known = Set(rows.map(\.candidateId))
        for row in matrix?.rows ?? [] where !known.contains(row.candidate.id) {
            rows.append(
                ResultadoRow(
                    candidateId: row.candidate.id,
                    name: row.candidate.name,
                    plaza: nil,
                    position: nil,
                    tied: false,
                    score: nil,
                    composition: nil,
                    byCircuit: Dictionary(
                        row.scores.map { ($0.circuitId, $0) },
                        uniquingKeysWith: { first, _ in first }
                    )
                )
            )
        }

        let ranked = rows
            .filter { !$0.hasNotDriven }
            .sorted { ($0.position ?? .max) < ($1.position ?? .max) }
        let notPresented = rows
            .filter(\.hasNotDriven)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return ResultadosData(
            convocatoriaName: ranking.convocatoria.name,
            convocatoriaStatus: ranking.convocatoria.status,
            circuits: matrix?.circuits ?? [],
            ranked: ranked,
            notPresented: notPresented
        )
    }

}

// MARK: - Orden

/// Cómo se ordenan las filas con nota.
///
/// Heredado del ranking, que ofrecía tres órdenes. «Mejor nota» se ha quedado
/// por el camino a propósito: el puesto ya se asigna por nota descendente, así
/// que producía exactamente la misma lista. Solo se diferenciaban en dónde
/// caían los ausentes, y ésos ahora van en su propia sección.
///
/// «Más recorridos completados» sí sobrevive, y es el que contesta la pregunta
/// de la rotación: a quién le toca conducir.
enum ResultadosSortMode: String, CaseIterable, Identifiable, Sendable {
    case position
    case completedDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .position:            "Por puesto"
        case .completedDescending: "Más recorridos completados"
        }
    }

    func apply(_ rows: [ResultadoRow]) -> [ResultadoRow] {
        switch self {
        case .position:
            // Quien no tiene puesto va al final, no al principio como si fuera
            // el puesto cero.
            return rows.sorted { ($0.position ?? .max) < ($1.position ?? .max) }
        case .completedDescending:
            return rows.sorted { left, right in
                let a = left.composition?.completedRequired ?? left.byCircuit.values.count { $0.score != nil }
                let b = right.composition?.completedRequired ?? right.byCircuit.values.count { $0.score != nil }
                if a != b { return a > b }
                // Empate: se rompe por puesto, para que la lista sea estable.
                return (left.position ?? .max) < (right.position ?? .max)
            }
        }
    }
}

private extension Collection {
    func count(where predicate: (Element) -> Bool) -> Int {
        reduce(0) { predicate($1) ? $0 + 1 : $0 }
    }
}

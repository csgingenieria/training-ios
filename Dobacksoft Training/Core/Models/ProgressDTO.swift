import Foundation

/// `GET /api/v1/me/progress` — cómo va el aspirante.
///
/// Es la pantalla que más piden y la única del portal que el cliente no tenía
/// en absoluto. Reúne tres cosas que hasta ahora vivían separadas: la
/// composición de la nota, el historial de intentos y la evolución por
/// recorrido, que es la que no existía por ningún otro camino.
///
/// Los cuatro campos de la composición reutilizan los nombres de
/// `StandingDTO` a propósito, así que se decodifican en `GradeComposition`, el
/// tipo que ya existe: un segundo vocabulario para los mismos cuatro números
/// obligaría a un segundo DTO que decir lo mismo de otra forma.
nonisolated struct ProgressDTO: Sendable {
    let candidate: ProgressCandidateDTO?
    let convocatoria: ProgressConvocatoriaDTO?
    let activeEnrollments: [ProgressEnrollmentDTO]

    /// La nota oficial. **No se enseña sin `presented`**: ver `displayScore`.
    let score: Double?

    /// Si hay nota que enseñar.
    ///
    /// Obligatorio y no derivable de `score`: `canonical_nota` devuelve `0.0`
    /// tanto para un cero real como para «todavía nada», porque necesita un
    /// número para ordenar. Sin este booleano la pantalla le escribe un «0,0» a
    /// quien nadie ha calificado.
    let presented: Bool?

    // MARK: Composición de la nota
    //
    // Planos y opcionales, exactamente como en `StandingDTO`: son los mismos
    // cuatro números con los mismos nombres, y `composition` los reúne. Repetir
    // aquí la forma de allí es lo que permite que la vista de la composición se
    // reutilice tal cual.

    let requiredRoutes: [String]?
    let completedRequired: Int?
    let pendingRequired: Int?
    let scoreOfCompleted: Double?

    /// De qué está hecha la nota, o `nil` si el contrato no la trae entera.
    var composition: GradeComposition? {
        guard let completedRequired, let pendingRequired else { return nil }
        return GradeComposition(
            requiredRoutes: requiredRoutes,
            completedRequired: completedRequired,
            pendingRequired: pendingRequired,
            scoreOfCompleted: scoreOfCompleted
        )
    }

    let attempts: [AttemptSummaryDTO]
    let evolution: [ProgressEvolutionDTO]

    /// El RECORRIDO cuya última vuelta puntuó más alto y más bajo.
    ///
    /// **No son el mejor y el peor intento.** Quien sacó un 10 y luego un 6 en
    /// el mismo recorrido lo tiene aquí como `worstRoute`, mientras ese 10
    /// sigue marcado `isCurrentBest` en la lista. Las dos cosas son ciertas y
    /// responden a preguntas distintas: esta pantalla habla de progreso, así
    /// que mira la última vuelta.
    let bestRoute: ProgressRouteExtremeDTO?
    let worstRoute: ProgressRouteExtremeDTO?

    /// La nota, o `nil` si no hay ninguna que enseñar.
    var displayScore: Double? { presented == true ? score : nil }

    /// Si vale la pena pintar el bloque de mejor y peor recorrido.
    ///
    /// Con un solo recorrido calificado los dos son el MISMO, y decirlo dos
    /// veces no informa de nada. El API manda los dos porque el dato es cierto;
    /// la decisión de no enseñarlos es del cliente, igual que en la web.
    var extremesAreWorthShowing: Bool {
        guard let best = bestRoute, let worst = worstRoute else { return false }
        return best.routeCode != worst.routeCode
    }
}

nonisolated extension ProgressDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            candidate: try c.decodeIfPresent(ProgressCandidateDTO.self, forKey: .candidate),
            convocatoria: try c.decodeIfPresent(ProgressConvocatoriaDTO.self, forKey: .convocatoria),
            activeEnrollments: try c.decodeIfPresent([ProgressEnrollmentDTO].self, forKey: .activeEnrollments) ?? [],
            score: try c.decodeIfPresent(Double.self, forKey: .score),
            presented: try c.decodeIfPresent(Bool.self, forKey: .presented),
            requiredRoutes: try c.decodeIfPresent([String].self, forKey: .requiredRoutes),
            completedRequired: try c.decodeIfPresent(Int.self, forKey: .completedRequired),
            pendingRequired: try c.decodeIfPresent(Int.self, forKey: .pendingRequired),
            scoreOfCompleted: try c.decodeIfPresent(Double.self, forKey: .scoreOfCompleted),
            attempts: try c.decodeIfPresent([AttemptSummaryDTO].self, forKey: .attempts) ?? [],
            evolution: try c.decodeIfPresent([ProgressEvolutionDTO].self, forKey: .evolution) ?? [],
            bestRoute: try c.decodeIfPresent(ProgressRouteExtremeDTO.self, forKey: .bestRoute),
            worstRoute: try c.decodeIfPresent(ProgressRouteExtremeDTO.self, forKey: .worstRoute)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case candidate, convocatoria, activeEnrollments, score, presented
        case requiredRoutes, completedRequired, pendingRequired, scoreOfCompleted
        case attempts, evolution, bestRoute, worstRoute
    }
}

// MARK: - Evolución por recorrido

/// La última vuelta de un recorrido, contra la anterior y contra la nota.
nonisolated struct ProgressEvolutionDTO: Sendable, Identifiable, Hashable {
    let routeCode: String?
    let label: String?

    /// La nota de la ÚLTIMA vuelta de este recorrido, no la mejor.
    let score: Double?

    /// La vuelta anterior, o `nil` si es la primera.
    let previousScore: Double?

    let trend: ProgressTrend?

    /// Diferencia contra la nota OFICIAL del aspirante, no contra su mejor
    /// intento.
    ///
    /// Con recorridos exigidos la nota oficial es una media que cuenta ceros,
    /// así que un recorrido puede marcar +4,0 siendo justamente donde está su
    /// mejor intento. El nombre lo dice para que la pantalla no rotule otra
    /// cosa.
    ///
    /// ⚠ El minuendo incluye recorridos de PRÁCTICAS y el sustraendo no: la
    /// nota oficial las excluye. Así que una práctica se compara contra la nota
    /// del examen. Es el comportamiento de la web y no se corrige aquí.
    let diffVsScore: Double?

    let attemptId: String?

    var id: String { attemptId ?? routeCode ?? UUID().uuidString }
}

nonisolated extension ProgressEvolutionDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            routeCode: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .routeCode)),
            label: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .label)),
            score: try c.decodeIfPresent(Double.self, forKey: .score),
            previousScore: try c.decodeIfPresent(Double.self, forKey: .previousScore),
            // Como `AttemptState`: se lee como texto y se traduce, para que un
            // valor futuro deje `nil` en vez de tumbar la entrada entera.
            trend: ProgressTrend(apiValue: try c.decodeIfPresent(String.self, forKey: .trend)),
            diffVsScore: try c.decodeIfPresent(Double.self, forKey: .diffVsScore),
            attemptId: try c.decodeIfPresent(String.self, forKey: .attemptId)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case routeCode, label, score, previousScore, trend, diffVsScore, attemptId
    }
}

/// Hacia dónde va la última vuelta de un recorrido.
nonisolated enum ProgressTrend: Sendable, Hashable {
    case subiendo, bajando, estable
    /// La PRIMERA vuelta de ese recorrido. No es «sin datos»: es un hecho, y la
    /// pantalla tiene que decirlo en vez de dejar un hueco.
    case primer

    init?(apiValue: String?) {
        switch (apiValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "subiendo": self = .subiendo
        case "bajando":  self = .bajando
        case "estable":  self = .estable
        case "primer":   self = .primer
        default:         return nil
        }
    }

    var isFirstLap: Bool { self == .primer }

    var label: String {
        switch self {
        case .subiendo: "Mejora"
        case .bajando:  "Baja"
        case .estable:  "Se mantiene"
        case .primer:   "Primera vuelta"
        }
    }

    /// Sin flecha en la primera vuelta: no hay nada contra lo que comparar y
    /// una flecha plana se leería como «no ha mejorado».
    var systemImage: String? {
        switch self {
        case .subiendo: "arrow.up.right"
        case .bajando:  "arrow.down.right"
        case .estable:  "arrow.right"
        case .primer:   nil
        }
    }
}

// MARK: - Extremos, candidato, convocatoria

nonisolated struct ProgressRouteExtremeDTO: Sendable, Hashable {
    let routeCode: String?
    let label: String?
    let score: Double?
    let attemptId: String?
}

nonisolated extension ProgressRouteExtremeDTO: Decodable {}

nonisolated struct ProgressCandidateDTO: Sendable, Hashable {
    let id: String?
    let name: String?
    /// El número de INSCRIPCIÓN que el aspirante teclea en la tablet, no una
    /// posición ni un cupo. Viaja `null` cuando no lo tiene; la web usa «—».
    let plaza: String?
}

nonisolated extension ProgressCandidateDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(String.self, forKey: .id),
            name: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .name)),
            plaza: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .plaza))
        )
    }

    private enum CodingKeys: String, CodingKey { case id, name, plaza }
}

nonisolated struct ProgressConvocatoriaDTO: Sendable, Hashable {
    let id: String?
    let name: String?
    /// Cuándo se CERRÓ la convocatoria. `nil` mientras sigue abierta — no es un
    /// plazo futuro, así que la pantalla no puede rotular «cierra el».
    let closedAt: String?

    /// Si el acta está emitida.
    ///
    /// Lo encontró el cruce contra la respuesta REAL: viajaba y el cliente lo
    /// tiraba en silencio. No estaba en ninguna nota que nos pasaran.
    ///
    /// **No decide lo que dice la pantalla, y es deliberado.** El backend lo
    /// calcula como `status in {CLOSED, LOCKED}`, y `GradeFinality` separa esos
    /// dos a propósito: `LOCKED` es el único estado en que la nota es
    /// inamovible, porque con `CLOSED` el administrador dispone de 24 horas
    /// para revertir el cierre. Llamar «definitiva» a una nota que aún puede
    /// moverse es afirmar de más sobre una persona en una oposición pública.
    ///
    /// Así que este campo es menos preciso que lo que el cliente ya deriva, y
    /// cablearlo al rótulo sería una rebaja disfrazada de simplificación. Se
    /// decodifica para no perderlo y para poder contrastarlo; el rótulo sigue
    /// saliendo de `GradeFinality`.
    let finalScorePublished: Bool?
}

nonisolated extension ProgressConvocatoriaDTO: Decodable {}

nonisolated struct ProgressEnrollmentDTO: Sendable, Hashable, Identifiable {
    let convocatoriaId: String?
    let name: String?

    /// El número de inscripción de ESTA convocatoria.
    ///
    /// Se me escapaba: viajaba en la respuesta real y el DTO lo tiraba. El
    /// barrido contra el fixture no lo cazó porque comparaba el nombre contra
    /// todo el directorio, y `plaza` existía en OTRO tipo — un falso negativo,
    /// que es peor que un falso positivo porque dice que está cubierto.
    ///
    /// Importa de verdad en `/me/pin`: la tablet pide el PIN **y** este número,
    /// y sin él la pantalla del PIN se queda a medias delante del camión.
    let plaza: String?

    var id: String { convocatoriaId ?? name ?? "" }
}

nonisolated extension ProgressEnrollmentDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            convocatoriaId: try c.decodeIfPresent(String.self, forKey: .convocatoriaId),
            name: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .name)),
            plaza: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .plaza))
        )
    }

    private enum CodingKeys: String, CodingKey { case convocatoriaId, name, plaza }
}

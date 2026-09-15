import Foundation

nonisolated struct AttemptSummaryDTO: Sendable, Identifiable, Hashable {
    let id: String
    let route: AttemptRouteDTO?
    let score: Double?
    let dataQuality: String?

    /// Calidad clasificada. `nil` cuando el backend no la envió o el valor es
    /// desconocido — en ese caso no se pinta insignia.
    var quality: DataQuality? { DataQuality(apiValue: dataQuality) }
    let createdAt: String?

    // MARK: - Añadidos el 2026-09-07 con el bloque A
    //
    // Llegan en las DOS listas: `/me/progress` y
    // `/me/convocatorias/<id>/attempts` comparten consulta, filtro, orden y
    // constructor. Y el endpoint que ya existía pasó a incluir intentos
    // `PROCESSING`, que es de dónde sale la necesidad de `state`.
    //
    // Todos opcionales aunque el contrato prometa algunos: la app desplegada
    // tiene que sobrevivir a un servidor más viejo, y un campo no opcional
    // tumbaría la lista ENTERA en vez del campo.

    /// Por qué tiene o no tiene nota.
    ///
    /// El contrato dice que nunca es nulo; aquí es opcional porque «este
    /// servidor no lo manda» y «este intento no tiene estado» son hechos
    /// distintos y solo el primero es real.
    let state: AttemptState?

    /// El intento que cuenta HOY en ese recorrido.
    ///
    /// `false` cuando no hay inscripción —intentos creados a mano, sin
    /// tablet—: marcar el único que hay como «el mejor» sería inventarlo.
    let isCurrentBest: Bool?

    /// Cuándo terminó la vuelta. ISO 8601.
    let endedAt: String?

    /// Kilómetros del RECORRIDO, no de la vuelta. `nil` cuando el recorrido no
    /// los declara: un cero diría que mide cero.
    let distanceKm: Double?

    /// Minutos del RECORRIDO, con el mismo criterio que `distanceKm`.
    let durationMin: Int?

    /// Con valores por defecto para todo lo opcional.
    ///
    /// Sustituye al inicializador sintetizado a propósito: al añadir los cinco
    /// campos del bloque A, el sintetizado obligó a tocar cada sitio que
    /// construía un intento a mano solo para pasar cinco `nil`. El contrato
    /// va a seguir creciendo, y esa fricción no aporta nada.
    init(
        id: String,
        route: AttemptRouteDTO? = nil,
        score: Double? = nil,
        dataQuality: String? = nil,
        createdAt: String? = nil,
        state: AttemptState? = nil,
        isCurrentBest: Bool? = nil,
        endedAt: String? = nil,
        distanceKm: Double? = nil,
        durationMin: Int? = nil
    ) {
        self.id = id
        self.route = route
        self.score = score
        self.dataQuality = dataQuality
        self.createdAt = createdAt
        self.state = state
        self.isCurrentBest = isCurrentBest
        self.endedAt = endedAt
        self.distanceKm = distanceKm
        self.durationMin = durationMin
    }
}

nonisolated extension AttemptSummaryDTO: Decodable {
    /// Decodifica a mano para que `state` sea tolerante.
    ///
    /// Con la conformidad sintetizada, un `state` que esta versión no
    /// reconociera lanzaría desde el enum y `decodeIfPresent` propagaría el
    /// error: se caería el intento ENTERO por un campo, y en una lista, todos.
    /// Aquí se lee como texto y se traduce; lo que no se reconoce queda `nil`,
    /// que es lo que el tipo opcional ya prometía.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            route: try c.decodeIfPresent(AttemptRouteDTO.self, forKey: .route),
            score: try c.decodeIfPresent(Double.self, forKey: .score),
            dataQuality: try c.decodeIfPresent(String.self, forKey: .dataQuality),
            createdAt: try c.decodeIfPresent(String.self, forKey: .createdAt),
            state: AttemptState(apiValue: try c.decodeIfPresent(String.self, forKey: .state)),
            isCurrentBest: try c.decodeIfPresent(Bool.self, forKey: .isCurrentBest),
            endedAt: try c.decodeIfPresent(String.self, forKey: .endedAt),
            distanceKm: try c.decodeIfPresent(Double.self, forKey: .distanceKm),
            durationMin: try c.decodeIfPresent(Int.self, forKey: .durationMin)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, route, score, dataQuality, createdAt
        case state, isCurrentBest, endedAt, distanceKm, durationMin
    }
}

/// Por qué un intento tiene o no tiene nota.
///
/// Existe porque la lista pasó a traer intentos en curso, y sin esto un
/// aspirante no puede distinguir el intento cuya nota está por llegar del que
/// no la va a tener nunca. Decirle lo mismo a los dos lo deja esperando algo
/// que no va a pasar.
nonisolated enum AttemptState: Sendable, Hashable {
    /// Calificado.
    case conNota
    /// Sin nota todavía: faltan los datos del camión, y llegarán.
    case esperando
    /// Quedó fuera de los mínimos de validez. No va a tener nota.
    case noEvaluable

    init?(apiValue: String?) {
        switch (apiValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "CON_NOTA":     self = .conNota
        case "ESPERANDO":    self = .esperando
        case "NO_EVALUABLE": self = .noEvaluable
        default:             return nil
        }
    }

    /// Si la nota todavía puede llegar. Es la diferencia que justifica el campo.
    var gradeMayStillArrive: Bool { self == .esperando }

    var label: String {
        switch self {
        case .conNota:     "Calificado"
        case .esperando:   "Pendiente de datos"
        case .noEvaluable: "No evaluable"
        }
    }

    /// La frase que explica el estado sin culpar al aspirante: los tres motivos
    /// son del sistema o del camión, ninguno suyo.
    var detail: String {
        switch self {
        case .conNota:
            "Este intento ya tiene nota."
        case .esperando:
            "Faltan datos del camión. La nota aparecerá cuando lleguen."
        case .noEvaluable:
            "Los datos registrados no permiten calificar este intento."
        }
    }
}

nonisolated struct MyAttemptsListDTO: Sendable {
    let items: [AttemptSummaryDTO]
}

nonisolated extension MyAttemptsListDTO: Decodable {}

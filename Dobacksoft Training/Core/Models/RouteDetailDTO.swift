import Foundation

/// `GET /api/v1/me/routes/<code>` — el detalle de un recorrido, bloque D.
///
/// El último del pedido, y el que cierra el portal del aspirante.
struct RouteDetailDTO: Sendable {
    let route: RouteInfoDTO?
    let waypoints: [RouteWaypointDTO]

    /// La misma forma que en `/me/progress` y en la lista de la convocatoria:
    /// un solo contrato del intento en las cuatro superficies que lo devuelven.
    let attempts: [AttemptSummaryDTO]

    let stats: RouteStatsDTO?
    let candidate: ProgressCandidateDTO?
    let convocatoria: ProgressConvocatoriaDTO?

    /// Los waypoints que se pueden dibujar, en orden.
    ///
    /// Uno sin coordenadas se descarta: un punto inventado cambiaría la forma
    /// del recorrido en el mapa.
    var drawableRoute: [GpsCoordinateDTO] {
        waypoints.sorted { ($0.order ?? 0) < ($1.order ?? 0) }.compactMap(\.coordinate)
    }
}

nonisolated extension RouteDetailDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            route: try c.decodeIfPresent(RouteInfoDTO.self, forKey: .route),
            waypoints: try c.decodeIfPresent([RouteWaypointDTO].self, forKey: .waypoints) ?? [],
            attempts: try c.decodeIfPresent([AttemptSummaryDTO].self, forKey: .attempts) ?? [],
            stats: try c.decodeIfPresent(RouteStatsDTO.self, forKey: .stats),
            candidate: try c.decodeIfPresent(ProgressCandidateDTO.self, forKey: .candidate),
            convocatoria: try c.decodeIfPresent(ProgressConvocatoriaDTO.self, forKey: .convocatoria)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case route, waypoints, attempts, stats, candidate, convocatoria
    }
}

// MARK: - El recorrido

struct RouteInfoDTO: Sendable, Hashable {
    let code: String?
    let name: String?
    let description: String?
    let distanceKm: Double?
    let durationMin: Int?

    /// Si sigue en el catálogo. Mismo criterio de tres estados que en
    /// `AttemptRouteDTO.active`.
    let active: Bool?

    /// Si el recorrido cuenta para la nota oficial.
    ///
    /// Con `rutasExigidas` declaradas solo los exigidos entran; **sin ellas
    /// cuentan TODOS** (mejor intento global), así que ahí llega `true`.
    let required: Bool?

    /// Si cuenta para la nota, o `nil` si el contrato no lo dice.
    ///
    /// Ausente **no es `false`**: afirmar que un recorrido no cuenta es tan
    /// equivocado como afirmar que sí, y de esa frase depende que el aspirante
    /// entienda por qué su 10 no le movió la nota.
    var countsTowardsTheGrade: Bool? { required }

    var displayName: String? { name ?? code }
}

nonisolated extension RouteInfoDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            code: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .code)),
            name: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .name)),
            description: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .description)),
            distanceKm: try c.decodeIfPresent(Double.self, forKey: .distanceKm),
            durationMin: try c.decodeIfPresent(Int.self, forKey: .durationMin),
            active: try c.decodeIfPresent(Bool.self, forKey: .active),
            required: try c.decodeIfPresent(Bool.self, forKey: .required)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case code, name, description, distanceKm, durationMin, active, required
    }
}

struct RouteWaypointDTO: Sendable, Hashable, Identifiable {
    let order: Int?
    let lat: Double?
    let lng: Double?
    let name: String?

    var id: Int { order ?? 0 }

    var coordinate: GpsCoordinateDTO? {
        guard let lat, let lng else { return nil }
        return GpsCoordinateDTO(lat: lat, lng: lng)
    }
}

nonisolated extension RouteWaypointDTO: Decodable {}

// MARK: - Los números del recorrido

/// Cuántas vueltas y cómo salieron.
struct RouteStatsDTO: Sendable, Hashable {
    /// Los intentos **con nota**.
    ///
    /// No «cerrados», y el backend lo renombró por eso: el estado derivado no
    /// distingue un cerrado sin nota de uno que espera los datos del camión, así
    /// que «cerrados» habría sido un número que no cuenta cerrados.
    let scoredAttempts: Int?

    /// Todos los que condujo, calificados o no.
    let listedAttempts: Int?

    let bestScore: Double?
    let bestAttemptId: String?

    /// La ÚLTIMA vuelta. Puede no ser la mejor, y en esta pantalla es
    /// justamente donde se ve.
    let lastScore: Double?
    let lastAttemptId: String?

    /// El instante de la última vuelta. Nunca falta si hay `lastScore`: son de
    /// la misma vuelta, y una nota sin fecha deja al aspirante sin poder
    /// situarla.
    let lastAt: String?

    /// Si condujo vueltas que todavía no tienen nota.
    ///
    /// Es la diferencia entre los dos números, y merece decirse: quien ve «3
    /// vueltas» y una sola nota necesita saber que las otras dos no se han
    /// perdido.
    var hasUngradedAttempts: Bool {
        guard let scoredAttempts, let listedAttempts else { return false }
        return listedAttempts > scoredAttempts
    }
}

nonisolated extension RouteStatsDTO: Decodable {}

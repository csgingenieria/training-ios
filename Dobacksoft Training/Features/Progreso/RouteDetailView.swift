import SwiftUI
import MapKit

/// El detalle de un recorrido: qué es, por dónde va y cómo le ha ido en él.
///
/// Se llega desde una fila de «Mi progreso», que es donde el aspirante se
/// pregunta «¿y en este cómo voy?».
struct RouteDetailView: View {
    let code: String
    var convocatoriaId: String?
    var convocatoriaName: String?

    @Environment(AuthSession.self) private var auth
    @State private var state: DetailState = .loading

    enum DetailState {
        case loading
        case loaded(RouteDetailDTO)
        case notFound(NotFoundReason)
        case error(String)
    }

    var body: some View {
        ScrollView {
            content
                .readableWidth()
                .padding(.horizontal, Theme.spacing.base.value)
                .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationTitle(title)
        .navigationDestination(for: ProgresoAttemptRoute.self) { ruta in
            AttemptDetailView(
                attemptId: ruta.attemptId,
                convocatoriaName: ruta.convocatoriaName,
                finality: GradeFinality(convocatoriaClosedAt: ruta.convocatoriaClosedAt),
                convocatoriaClosedAt: ruta.convocatoriaClosedAt
            )
        }
        .task(id: code) { await load() }
        .refreshable { await load() }
    }

    private var title: String {
        if case .loaded(let detalle) = state {
            return detalle.route?.displayName ?? code
        }
        return code
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            VStack(spacing: Theme.spacing.md.value) {
                ProgressView().tint(Color.brand)
                Text("Cargando el recorrido…")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 200)

        case .loaded(let detalle):
            VStack(spacing: Theme.spacing.lg.value) {
                infoCard(detalle)
                if detalle.drawableRoute.count > 1 {
                    routeMap(detalle)
                }
                if let stats = detalle.stats {
                    statsCard(stats)
                }
                attemptsSection(detalle)
            }

        case .notFound(let reason):
            ContentUnavailableView(
                reason.title,
                systemImage: reason.symbol,
                description: Text(reason.detail)
            )
            .cardStyle()

        case .error(let mensaje):
            ContentUnavailableView {
                Label("No se ha podido cargar el recorrido", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(mensaje)
            } actions: {
                Button("Reintentar") { Task { await load() } }
                    .buttonStyle(.brandPrimary(fullWidth: false))
                    .accessibilityIdentifier("recorrido.retry")
            }
            .cardStyle()
        }
    }

    // MARK: - Qué recorrido es

    @ViewBuilder
    private func infoCard(_ detalle: RouteDetailDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            if let nombre = detalle.route?.name, let codigo = detalle.route?.code, nombre != codigo {
                Text(codigo)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }

            if let descripcion = detalle.route?.description {
                Text(descripcion)
                    .font(.bodyText)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let km = detalle.route?.distanceKm, let min = detalle.route?.durationMin {
                Text("\(ScoreFormat.attempt(km)) km · \(min) min previstos")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }

            // La frase que explica por qué un 10 aquí puede no mover la nota.
            // Solo con un `false` explícito: sin el campo no se afirma nada,
            // porque decir que no cuenta cuando sí cuenta es igual de falso.
            if detalle.route?.countsTowardsTheGrade == false {
                Divider()
                Text(RouteDetailCopy.notRequired)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if detalle.route?.active == false {
                Text(RouteDetailCopy.withdrawn)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Por dónde va

    @ViewBuilder
    private func routeMap(_ detalle: RouteDetailDTO) -> some View {
        Map {
            MapPolyline(coordinates: detalle.drawableRoute.map(\.clLocation))
                .stroke(Color.brand, style: .init(lineWidth: 4, lineCap: .round))

            ForEach(detalle.waypoints) { punto in
                if let coordenada = punto.coordinate {
                    Marker(punto.name ?? "Punto \(punto.order ?? 0)", coordinate: coordenada.clLocation)
                        .tint(Color.brand)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous))
        .accessibilityLabel("Trazado del recorrido con \(detalle.waypoints.count) puntos de paso")
    }

    // MARK: - Cómo le ha ido

    @ViewBuilder
    private func statsCard(_ stats: RouteStatsDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            HStack(spacing: Theme.spacing.md.value) {
                if let mejor = stats.bestScore {
                    StandingMetric(title: "Mejor vuelta", value: ScoreFormat.attempt(mejor))
                }
                if let ultima = stats.lastScore {
                    StandingMetric(title: "Última vuelta", value: ScoreFormat.attempt(ultima))
                }
            }

            if let fecha = stats.lastAt, let texto = APIDate.shortDateTime(fecha) {
                Text("Última vuelta: \(texto)")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }

            // Los dos números cuentan cosas distintas, y la diferencia merece
            // decirse: quien ve tres vueltas y una nota necesita saber que las
            // otras dos no se han perdido.
            Text(RouteDetailCopy.counts(stats))
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func attemptsSection(_ detalle: RouteDetailDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Sus vueltas en este recorrido")
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Theme.spacing.xs.value)

            if detalle.attempts.isEmpty {
                ContentUnavailableView {
                    Label("Todavía no ha conducido este recorrido", systemImage: "steeringwheel")
                } description: {
                    Text("Aquí aparecerán sus vueltas en cuanto conduzca este recorrido.")
                }
                .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(detalle.attempts) { intento in
                        NavigationLink(value: ProgresoAttemptRoute(
                            attemptId: intento.id,
                            convocatoriaName: detalle.convocatoria?.name ?? convocatoriaName,
                            convocatoriaClosedAt: detalle.convocatoria?.closedAt
                        )) {
                            AttemptSummaryRow(attempt: intento)
                        }
                        .buttonStyle(.plain)
                        if intento.id != detalle.attempts.last?.id {
                            Divider().padding(.leading, Theme.spacing.base.value)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                        .fill(Color.paperElevated)
                )
                .themedShadow(.small)
            }
        }
    }

    @MainActor
    private func load() async {
        do {
            let detalle = try await auth.authorized { token in
                try await APIClient.shared.myRoute(
                    code: code,
                    convocatoriaId: convocatoriaId,
                    accessToken: token
                )
            }
            state = .loaded(detalle)
        } catch let error as APIError where error.notFoundReason != nil {
            state = .notFound(error.notFoundReason ?? .resourceMissing)
        } catch let error as APIError {
            state = .error(error.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

/// Lo que dice la pantalla del recorrido.
nonisolated enum RouteDetailCopy {
    /// Por qué una nota alta aquí puede no mover la nota oficial.
    static let notRequired =
        "Este recorrido no está entre los exigidos por la convocatoria, así que sus vueltas aquí no intervienen en la nota oficial."

    /// El recorrido se retiró del catálogo. No borra las vueltas ya conducidas.
    static let withdrawn =
        "Este recorrido ya no se ofrece. Sus vueltas anteriores siguen contando igual."

    /// Las dos cuentas, cuando difieren.
    ///
    /// Con todas calificadas se dice una sola cosa: repetir el mismo número dos
    /// veces no informa de nada.
    static func counts(_ stats: RouteStatsDTO) -> String {
        let conducidas = stats.listedAttempts ?? 0
        let vuelta = conducidas == 1 ? "vuelta" : "vueltas"

        guard stats.hasUngradedAttempts else {
            return "\(conducidas) \(vuelta) conducidas, todas calificadas."
        }
        let calificadas = stats.scoredAttempts ?? 0
        return "\(conducidas) \(vuelta) conducidas, \(calificadas) con nota. Las demás siguen pendientes de datos."
    }
}

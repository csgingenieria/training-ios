import SwiftUI

/// «Cómo voy» — la pantalla que faltaba entera.
///
/// El portal la tiene y el cliente no la tenía por ningún camino: el aspirante
/// veía su puesto y su lista de intentos, pero no cómo evoluciona en cada
/// recorrido, que es la pregunta que se hace de verdad entre vuelta y vuelta.
struct ProgresoView: View {
    /// La convocatoria elegida. `nil` deja que el backend use su inscripción
    /// activa — que es lo correcto, y muy distinto de mandarle una cadena vacía.
    var convocatoriaId: String?

    @Environment(AuthSession.self) private var auth
    @State private var viewModel = ProgressViewModel()

    var body: some View {
        ScrollView {
            content
                .readableWidth()
                .padding(.horizontal, Theme.spacing.base.value)
                .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationTitle("Mi progreso")
        .navigationDestination(for: ProgresoAttemptRoute.self) { ruta in
            AttemptDetailView(
                attemptId: ruta.attemptId,
                convocatoriaName: ruta.convocatoriaName,
                finality: GradeFinality(convocatoriaClosedAt: ruta.convocatoriaClosedAt),
                convocatoriaClosedAt: ruta.convocatoriaClosedAt,
                createdAt: ruta.createdAt
            )
        }
        .navigationDestination(for: ProgresoRouteRoute.self) { ruta in
            RouteDetailView(
                code: ruta.code,
                convocatoriaId: ruta.convocatoriaId,
                convocatoriaName: ruta.convocatoriaName
            )
        }
        .task(id: convocatoriaId) { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            VStack(spacing: Theme.spacing.md.value) {
                ProgressView().tint(Color.brand)
                Text("Cargando su progreso…")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 200)

        case .loaded(let progreso):
            VStack(spacing: Theme.spacing.lg.value) {
                gradeCard(progreso)
                if progreso.extremesAreWorthShowing {
                    extremesCard(progreso)
                }
                evolutionSection(progreso)
                refreshFooter
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
                Label("No se ha podido cargar su progreso", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(mensaje)
            } actions: {
                Button("Reintentar") { Task { await load() } }
                    .buttonStyle(.brandPrimary(fullWidth: false))
                    .accessibilityIdentifier("progreso.retry")
            }
            .cardStyle()
        }
    }

    // MARK: - La nota y de qué está hecha

    @ViewBuilder
    private func gradeCard(_ progreso: ProgressDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Su nota")
                .font(.metaCaption)
                .foregroundStyle(Color.muted)

            // `displayScore` y no `score`: la nota canónica vale 0,0 tanto para
            // un cero real como para «todavía nada», y escribirle un «0,0» a
            // quien nadie ha calificado es peor que no escribir nada.
            if let nota = progreso.displayScore {
                HStack(alignment: .firstTextBaseline, spacing: Theme.spacing.xs.value) {
                    Text(ScoreFormat.aggregate(nota))
                        .font(.display(size: 44, weight: .bold, italic: false, relativeTo: .largeTitle))
                        .foregroundStyle(Color.ink)
                    Text("sobre 10")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Su nota: \(ScoreFormat.spoken(nota, decimals: 2))")
            } else {
                Text(SnapshotCopy.notaNoDisponible)
                    .font(.cardTitle)
                    .foregroundStyle(Color.muted)
                Text("Todavía no consta ninguna calificación.")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }

            if let composicion = progreso.composition {
                Divider()
                GradeCompositionView(composition: composicion)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Mejor y peor recorrido

    /// Solo cuando informan. Con un recorrido calificado los dos son el mismo,
    /// y decirlo dos veces no dice nada: el API manda los dos porque el dato es
    /// cierto, y no pintarlos es decisión del cliente.
    @ViewBuilder
    private func extremesCard(_ progreso: ProgressDTO) -> some View {
        HStack(alignment: .top, spacing: Theme.spacing.base.value) {
            extreme("Mejor recorrido", progreso.bestRoute, symbol: "arrow.up.circle.fill")
            Divider().frame(maxHeight: 44)
            extreme("A mejorar", progreso.worstRoute, symbol: "arrow.down.circle.fill")
        }
        .cardStyle()
    }

    @ViewBuilder
    private func extreme(_ titulo: String, _ extremo: ProgressRouteExtremeDTO?, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
            Label(titulo, systemImage: symbol)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .labelStyle(.titleOnly)
            Text(extremo?.label ?? extremo?.routeCode ?? "—")
                .font(.bodyEmphasis)
                .foregroundStyle(Color.ink)
            if let nota = extremo?.score {
                Text(ScoreFormat.attempt(nota))
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Una parada de VoiceOver por columna: leer título, recorrido y nota
        // por separado obliga a recomponerlos de memoria.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [titulo, extremo?.label ?? extremo?.routeCode,
             extremo?.score.map { ScoreFormat.spoken($0, decimals: 1) }]
                .compactMap { $0 }.joined(separator: ", ")
        )
    }

    // MARK: - La evolución, que es lo que no existía

    @ViewBuilder
    private func evolutionSection(_ progreso: ProgressDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Recorrido a recorrido")
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Theme.spacing.xs.value)

            if progreso.evolution.isEmpty {
                ContentUnavailableView {
                    Label("Todavía no hay recorridos calificados", systemImage: "chart.line.uptrend.xyaxis")
                } description: {
                    Text("Aquí verá cómo evoluciona en cada recorrido en cuanto tenga vueltas calificadas.")
                } actions: {
                    Button("Actualizar") { Task { await load() } }
                        .buttonStyle(.brandPrimary(fullWidth: false))
                        .accessibilityIdentifier("progreso.refresh")
                }
                .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(progreso.evolution) { entrada in
                        row(entrada, convocatoriaName: progreso.convocatoria?.name)
                        if entrada.id != progreso.evolution.last?.id {
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

    @ViewBuilder
    private func row(_ entrada: ProgressEvolutionDTO, convocatoriaName: String?) -> some View {
        // La fila lleva al RECORRIDO, no al intento suelto: la pregunta de
        // esta pantalla es «¿cómo voy en este recorrido?», y desde su ficha se
        // alcanza cada vuelta. Sin código no hay destino.
        let destino = entrada.routeCode.map {
            ProgresoRouteRoute(
                code: $0,
                convocatoriaId: convocatoriaId,
                convocatoriaName: convocatoriaName
            )
        }

        Group {
            if let destino {
                NavigationLink(value: destino) { rowContent(entrada) }
                    .buttonStyle(.plain)
            } else {
                rowContent(entrada)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ProgresoRowCopy.accessibilityLabel(for: entrada))
        .accessibilityIdentifier("progreso.row")
    }

    @ViewBuilder
    private func rowContent(_ entrada: ProgressEvolutionDTO) -> some View {
        HStack(spacing: Theme.spacing.md.value) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entrada.label ?? entrada.routeCode ?? "Recorrido")
                    .font(.bodyEmphasis)
                    .foregroundStyle(Color.ink)
                Text(ProgresoRowCopy.subtitle(for: entrada))
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if let trend = entrada.trend, let symbol = trend.systemImage {
                Image(systemName: symbol)
                    .foregroundStyle(Color.muted)
                    .accessibilityHidden(true)
            }
            if let nota = entrada.score {
                Text(ScoreFormat.attempt(nota))
                    .font(.body(size: 20, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(Color.ink)
            } else {
                Text("Sin nota")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
        }
        .padding(Theme.spacing.base.value)
        .contentShape(Rectangle())
    }

    // MARK: - Pie

    @ViewBuilder
    private var refreshFooter: some View {
        if let refreshError = viewModel.refreshError {
            HStack(alignment: .top, spacing: Theme.spacing.sm.value) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(Color.warning)
                    .accessibilityHidden(true)
                Text(refreshError)
                    .font(.metaCaption)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Reintentar") { Task { await load() } }
                    .font(.metaCaption)
                    .foregroundStyle(Color.brand)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("progreso.retryRefresh")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(refreshError)
        } else if let lastUpdated = viewModel.lastUpdated {
            HStack(spacing: Theme.spacing.xs.value) {
                if viewModel.isRefreshing {
                    ProgressView().controlSize(.mini).tint(Color.muted)
                }
                Text("Actualizado a las \(APIDate.time(lastUpdated))")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityIdentifier("progreso.lastUpdated")
        }
    }

    private func load() async {
        await viewModel.load(convocatoriaId: convocatoriaId, auth: auth)
    }
}

/// Destino de navegación propio, para no depender del de otra pantalla.
struct ProgresoAttemptRoute: Hashable {
    let attemptId: String
    let convocatoriaName: String?

    /// Cuándo se cerró la convocatoria, o `nil` si sigue abierta.
    ///
    /// `/me/progress` y `/me/routes/<code>` no envían su estado, solo esta
    /// fecha, así que es de aquí de donde sale la aclaración legal de la nota
    /// en el detalle del intento. Viaja en la ruta porque quien la conoce es
    /// la pantalla de origen, no el destino.
    var convocatoriaClosedAt: String?

    /// Cuándo fue el intento, por lo mismo: el detalle no la recibe del API.
    var createdAt: String?
}

/// El detalle de un recorrido, desde su fila de progreso.
struct ProgresoRouteRoute: Hashable {
    let code: String
    let convocatoriaId: String?
    let convocatoriaName: String?
}

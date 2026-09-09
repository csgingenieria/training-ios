import SwiftUI

/// El estado de la lista de convocatorias.
///
/// Era la última pantalla de datos que seguía vaciándose a un spinner en cada
/// recarga y sustituyendo la lista cargada por un error — la disciplina que
/// `StandingViewModel` y `ProgressViewModel` ya tienen.
///
/// Era tolerable mientras los datos se cargaban una vez por arranque. Dejó de
/// serlo con `RefreshTicker`: volver a la app tras cinco minutos recarga solo,
/// y una cobertura mala en el pasillo le borraría al aspirante la lista que
/// estaba leyendo sin que él hubiera pedido nada.
@MainActor
@Observable
final class ConvocatoriasListViewModel {
    enum State: Equatable {
        case loading
        case loaded([ConvocatoriaSummaryDTO])
        case empty
        case error(String)
    }

    var state: State = .loading

    /// Refresco en curso SOBRE datos ya visibles.
    var isRefreshing = false

    /// El fallo del último refresco, cuando había datos que conservar.
    var refreshError: String?

    /// Cuándo se obtuvieron los datos que se están enseñando.
    var lastUpdated: Date?

    private let api: TrainingAPI
    private let now: @Sendable () -> Date

    init(api: TrainingAPI = APIClient.shared, now: @escaping @Sendable () -> Date = Date.init) {
        self.api = api
        self.now = now
    }

    func load(auth: AuthSession, isStudent: Bool) async {
        let teniaDatos: Bool
        if case .loaded = state { teniaDatos = true } else { teniaDatos = false }

        if teniaDatos { isRefreshing = true } else { state = .loading }
        defer { isRefreshing = false }

        do {
            let items = try await auth.authorized { [api] token in
                // Dos endpoints distintos con permisos distintos, no dos
                // formas de pedir lo mismo: el aspirante pide SUS
                // inscripciones, el instructor el catálogo.
                isStudent
                    ? try await api.myConvocatorias(accessToken: token)
                    : try await api.convocatorias(accessToken: token)
            }
            // Una respuesta vacía en un REFRESCO es real y se cree: a quien le
            // retiran la inscripción tiene que vérselo, y tratarlo como
            // «conserva la lista anterior» le enseñaría algo falso.
            state = items.isEmpty ? .empty : .loaded(items)
            refreshError = nil
            lastUpdated = now()
        } catch {
            // Una cancelación no es un fallo que contar: cambiar de
            // convocatoria a media carga cancela la anterior, y pintar su error
            // culparía al aspirante de algo que hizo la app.
            guard !Task.isCancelled, !error.isCancellation else { return }
            let mensaje = (error as? APIError)?.userMessage ?? error.localizedDescription
            if teniaDatos {
                // La hora NO se mueve: es la del dato que se está viendo.
                // Adelantarla fecharía cifras viejas como recientes, que es
                // peor que no fecharlas.
                refreshError = "\(mensaje) Se muestra el último dato consultado."
            } else {
                state = .error(mensaje)
            }
        }
    }
}

struct ConvocatoriasListView: View {
    @Environment(AuthSession.self) private var auth

    /// Opcional a propósito: las previsualizaciones no lo inyectan, y una
    /// pantalla no puede caerse por faltarle el motivo para recargar.
    @Environment(RefreshTicker.self) private var ticker: RefreshTicker?

    @State private var viewModel = ConvocatoriasListViewModel()
    @State private var searchText = ""
    @State private var scope: ConvocatoriaScope = .activas

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                loadingView
            case .empty:
                // Con «Actualizar»: a quien inscriben después de abrir la app
                // se le queda esta pantalla puesta, y el gesto de tirar hacia
                // abajo no funciona aquí —no hay contenedor con scroll— así
                // que sin botón no había forma de volver a preguntar.
                ContentUnavailableView {
                    Label("Sin convocatorias", systemImage: "tray.fill")
                } description: {
                    Text("No hay convocatorias visibles para su perfil.")
                } actions: {
                    Button("Actualizar") { Task { await load() } }
                        .buttonStyle(.brandPrimary(fullWidth: false))
                        .accessibilityIdentifier("convocatorias.refresh")
                }
            case .loaded(let items):
                let filtered = filter(items)
                if filtered.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if filtered.isEmpty {
                    // El filtro de ámbito vació la lista. Sin esta rama la
                    // pantalla quedaba en blanco: al final de campaña, con todo
                    // cerrado, el instructor no veía nada ni sabía que hay un
                    // selector arriba puesto en «En curso».
                    ContentUnavailableView {
                        Label("Sin convocatorias \(scope.title.lowercased())", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Hay \(items.count) convocatorias en total. Cambie el filtro para verlas.")
                    } actions: {
                        Button("Ver todas") { scope = .todas }
                            .buttonStyle(.brandPrimary(fullWidth: false))
                    }
                } else {
                    loadedList(filtered)
                }
            case .error(let msg):
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(msg)
                } actions: {
                    Button("Reintentar") { Task { await load() } }
                        .buttonStyle(.brandPrimary(fullWidth: false))
                }
            }
        }
        .navigationTitle("Convocatorias")
        // El destino vive en la RAÍZ de la sección, no dentro de la lista.
        //
        // Estaba dentro de `loadedList`, que solo se renderea con la lista
        // cargada y no vacía: mientras el estado pasaba por `.loading` el
        // destino desaparecía y con él la convocatoria abierta. Ahora que la
        // pila tiene `path` enlazado y sobrevive a los cambios de size class,
        // un destino que va y viene expulsaría la pantalla en cada recarga.
        .navigationDestination(for: ConvocatoriaSummaryDTO.self) { conv in
            ConvocatoriaDetailView(convocatoria: conv)
        }
        .searchable(text: $searchText, prompt: "Buscar convocatoria")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Un Picker(.menu) suelto en el toolbar se estira hasta ocupar
                // todo el ancho disponible: tres palabras cortas quedaban dentro
                // de una cápsula de media pantalla, con el texto pegado al borde
                // derecho. Envuelto en un Menu con etiqueta propia dimensiona al
                // contenido y, de paso, se lee como filtro y no como título.
                Menu {
                    Picker("Mostrar", selection: $scope) {
                        ForEach(ConvocatoriaScope.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label(scope.title, systemImage: "line.3.horizontal.decrease.circle")
                }
                .tint(Color.brand)
                .accessibilityLabel("Filtrar convocatorias. Actual: \(scope.title)")
            }
        }
        .task(id: ticker?.generation ?? 0) { await load() }
        .refreshable { await load() }
    }

    private func filter(_ items: [ConvocatoriaSummaryDTO]) -> [ConvocatoriaSummaryDTO] {
        let byScope = items.filter(scope.matches)
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return byScope }
        return byScope.filter {
            $0.name.lowercased().contains(query) ||
            ($0.description?.lowercased().contains(query) ?? false)
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Theme.spacing.md.value) {
            ProgressView()
                .tint(Color.brand)
            Text("Cargando convocatorias…")
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageBackground()
    }

    /// Cuándo se leyó esto, o por qué no se ha podido volver a leer.
    ///
    /// Existe porque ahora la pantalla se recarga sola al volver a la app: sin
    /// fecha, el aspirante no puede distinguir la lista de hace un minuto de la
    /// de ayer, y sin la nota del fallo no sabría que está viendo la de antes.
    /// El widget ya envejecía sus cifras; la app no.
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
                    .accessibilityIdentifier("convocatorias.retryRefresh")
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
            .accessibilityIdentifier("convocatorias.lastUpdated")
        }
    }

    @ViewBuilder
    private func loadedList(_ items: [ConvocatoriaSummaryDTO]) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.spacing.md.value) {
                ForEach(items) { conv in
                    NavigationLink(value: conv) {
                        ConvocatoriaRow(conv: conv)
                    }
                    .buttonStyle(.plain)
                    // Identidad estable para el recorrido automatizado: el
                    // nombre de la convocatoria depende de los datos.
                    .accessibilityIdentifier("convocatorias.row")
                }

                refreshFooter
            }
            .readableWidth()
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
    }

    private func load() async {
        await viewModel.load(auth: auth, isStudent: auth.user?.isStudent ?? false)
    }
}

struct ConvocatoriaRow: View {
    let conv: ConvocatoriaSummaryDTO

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            HStack(alignment: .top, spacing: Theme.spacing.sm.value) {
                Text(conv.name)
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let status = conv.status {
                    let estado = StatusVocabulary.convocatoria(status)
                    StatusBadge(text: estado.label, kind: estado.kind)
                }
            }

            if let descr = conv.description, !descr.isEmpty {
                Text(descr)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .lineLimit(2)
            }

            HStack(spacing: Theme.spacing.base.value) {
                metric(icon: "person.3.fill", text: "\(conv.totalCandidates) aspirantes")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.muted)
                    .accessibilityHidden(true)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Tocar para ver detalle")
    }

    private func metric(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.metaCaption)
        }
        .foregroundStyle(Color.muted)
    }


    private var accessibilitySummary: String {
        var parts: [String] = [conv.name]
        if let status = conv.status { parts.append(StatusVocabulary.convocatoria(status).label) }
        parts.append("\(conv.totalCandidates) aspirantes")
        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        ConvocatoriasListView()
            .environment(AuthSession.previewAuthenticated)
    }
}

/// Separa convocatorias en curso de las ya cerradas.
///
/// El portal web las presenta en dos listas distintas; aquí estaban todas
/// mezcladas y con el tiempo la lista se vuelve inservible: un instructor
/// trabaja sobre las abiertas y consulta las cerradas de tarde en tarde.
enum ConvocatoriaScope: String, CaseIterable, Identifiable {
    case activas
    case cerradas
    case todas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activas:  "En curso"
        case .cerradas: "Cerradas"
        case .todas:    "Todas"
        }
    }

    private static let closedStates: Set<String> = ["CLOSED", "LOCKED", "CERRADA"]

    func matches(_ convocatoria: ConvocatoriaSummaryDTO) -> Bool {
        guard self != .todas else { return true }
        let status = (convocatoria.status ?? "").uppercased()
        let isClosed = Self.closedStates.contains(status)
        return self == .cerradas ? isClosed : !isClosed
    }
}

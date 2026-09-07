import SwiftUI

@MainActor
@Observable
final class ConvocatoriasListViewModel {
    enum State {
        case loading
        case loaded([ConvocatoriaSummaryDTO])
        case empty
        case error(String)
    }

    var state: State = .loading

    func load(auth: AuthSession, isStudent: Bool) async {
        state = .loading
        do {
            let items = try await auth.authorized { token in
                isStudent
                    ? try await APIClient.shared.myConvocatorias(accessToken: token)
                    : try await APIClient.shared.convocatorias(accessToken: token)
            }
            state = items.isEmpty ? .empty : .loaded(items)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

struct ConvocatoriasListView: View {
    @Environment(AuthSession.self) private var auth
    @State private var viewModel = ConvocatoriasListViewModel()
    @State private var searchText = ""
    @State private var scope: ConvocatoriaScope = .activas

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                loadingView
            case .empty:
                ContentUnavailableView(
                    "Sin convocatorias",
                    systemImage: "tray.fill",
                    description: Text("No hay convocatorias visibles para su perfil.")
                )
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
        .task { await load() }
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
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationDestination(for: ConvocatoriaSummaryDTO.self) { conv in
            ConvocatoriaDetailView(convocatoria: conv)
        }
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
                metric(icon: "person.3.fill", text: "\(conv.totalCandidates) candidatos")
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
        parts.append("\(conv.totalCandidates) candidatos")
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

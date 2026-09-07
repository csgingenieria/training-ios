import SwiftUI

private struct ResultadoAttemptRoute: Hashable {
    let attemptId: String
}

private struct ResultadoStudentRoute: Hashable {
    let studentId: String
}

// MARK: - ViewModel

@MainActor
@Observable
final class ResultadosViewModel {
    enum State {
        case loading
        case loaded(ResultadosData)
        case empty
        case error(String)
    }

    var state: State = .loading

    /// Carga las dos fuentes a la vez.
    ///
    /// El ranking es obligatorio: sin él no hay orden de méritos y no hay
    /// pantalla. La matriz es opcional a propósito — si falla, se enseña el
    /// orden con las columnas vacías en vez de una pantalla de error. Un
    /// instructor que solo necesita saber quién va delante no debería perder la
    /// pantalla porque el endpoint de la matriz se haya caído.
    func load(convocatoriaId: String, auth: AuthSession) async {
        state = .loading
        do {
            let ranking = try await auth.authorized { token in
                try await APIClient.shared.ranking(convocatoriaId: convocatoriaId, accessToken: token)
            }
            let matrix = try? await auth.authorized { token in
                try await APIClient.shared.matrix(convocatoriaId: convocatoriaId, accessToken: token)
            }

            let data = ResultadosData.merge(ranking: ranking, matrix: matrix)
            state = data.totalCandidates == 0 ? .empty : .loaded(data)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

// MARK: - View

/// Orden de méritos y nota por recorrido, en una sola tabla.
///
/// Sustituye a «Ranking completo» y «Matriz de puntuaciones», que eran dos
/// destinos separados para la misma pregunta. Es la forma que ya tiene el
/// portal web en `/manager/resultados`, y el rótulo es el mismo por la misma
/// razón que allí: es lo que un instructor viene a buscar.
struct ResultadosView: View {
    let convocatoriaId: String

    /// Nombre de la convocatoria, para el detalle del intento.
    var convocatoriaName: String?

    @Environment(AuthSession.self) private var auth
    @State private var viewModel = ResultadosViewModel()
    @State private var sortMode: ResultadosSortMode = .position

    private let positionColumnWidth: CGFloat = 34
    private let nameColumnWidth: CGFloat = 150
    private let scoreColumnWidth: CGFloat = 62
    private let cellMinWidth: CGFloat = 62

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: Theme.spacing.md.value) {
                    ProgressView().tint(Color.brand)
                    Text("Cargando resultados…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground()

            case .empty:
                ContentUnavailableView(
                    "Sin resultados",
                    systemImage: "tablecells",
                    description: Text("No consta ningún aspirante inscrito en esta convocatoria.")
                )

            case .loaded(let data):
                content(data).pageBackground()

            case .error(let message):
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(message)
                } actions: {
                    Button("Reintentar") { Task { await load() } }
                        .buttonStyle(.brandPrimary(fullWidth: false))
                }
            }
        }
        .navigationTitle("Resultados")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .loaded = viewModel.state {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Ordenar", selection: $sortMode) {
                            ForEach(ResultadosSortMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    } label: {
                        Label("Ordenar", systemImage: "arrow.up.arrow.down")
                    }
                    .tint(Color.brand)
                    .accessibilityLabel("Ordenar. Actual: \(sortMode.title)")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(for: ResultadoAttemptRoute.self) { route in
            AttemptDetailView(attemptId: route.attemptId, convocatoriaName: convocatoriaName)
        }
        .navigationDestination(for: ResultadoStudentRoute.self) { route in
            StudentProfileView(studentId: route.studentId)
        }
    }

    private func load() async {
        await viewModel.load(convocatoriaId: convocatoriaId, auth: auth)
    }

    // MARK: - Contenido

    private func content(_ data: ResultadosData) -> some View {
        // El resumen y la nota al pie son prosa y viven FUERA del lienzo que
        // scrollea en horizontal: dentro, el nombre de la convocatoria se iba
        // de lado al mover la tabla y el texto del pie había que recortarlo a
        // 320 pt para que se pudiera leer. Solo la tabla scrollea en los dos
        // ejes, que es lo que lo necesita: con diez recorridos no entra de
        // ancho en ningún iPhone.
        VStack(alignment: .leading, spacing: 0) {
            summary(data)
            Divider()

            // Un ScrollView de dos ejes CENTRA su contenido en el eje que no
            // llena, así que una tabla más corta que la pantalla aparecía con
            // un hueco arriba y otro abajo, que se lee como que falta algo por
            // cargar. `maxHeight: .infinity` no lo corrige; darle como mínimo
            // la altura del viewport, sí: entonces no hay holgura que repartir.
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(sortMode.apply(data.ranked)) { row in
                                dataRow(row, circuits: data.circuits)
                                Divider()
                            }

                            if !data.notPresented.isEmpty {
                                notPresentedHeader(count: data.notPresented.count)
                                ForEach(data.notPresented) { row in
                                    dataRow(row, circuits: data.circuits)
                                    Divider()
                                }
                            }
                        } header: {
                            VStack(spacing: 0) {
                                headerRow(data.circuits)
                                Divider()
                            }
                            .background(Color.paperElevated)
                        }
                    }
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
            }

            Divider()
            footnote(data)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func summary(_ data: ResultadosData) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
            HStack(spacing: Theme.spacing.sm.value) {
                Text(data.convocatoriaName)
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                let estado = StatusVocabulary.convocatoria(data.convocatoriaStatus)
                StatusBadge(text: estado.label, kind: estado.kind)
            }
            HStack(spacing: Theme.spacing.sm.value) {
                Text("\(data.totalCandidates) aspirantes")
                Text("·")
                Text("\(data.realCircuitCount) recorridos")
                if !data.notPresented.isEmpty {
                    Text("·")
                    Text("\(data.notPresented.count) sin conducir")
                }
            }
            .font(.metaCaption)
            .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.spacing.base.value)
        .padding(.vertical, Theme.spacing.md.value)
    }

    // MARK: - Cabecera de columnas

    private func headerRow(_ circuits: [MatrixCircuitDTO]) -> some View {
        HStack(spacing: 0) {
            Text("#")
                .font(.body(size: 12, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(Color.muted)
                .frame(width: positionColumnWidth, alignment: .center)

            Text("Aspirante")
                .font(.body(size: 12, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(Color.muted)
                .frame(width: nameColumnWidth, alignment: .leading)
                .padding(.horizontal, Theme.spacing.sm.value)

            Text("Nota")
                .font(.body(size: 12, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(Color.muted)
                .frame(width: scoreColumnWidth, alignment: .trailing)
                .padding(.trailing, Theme.spacing.sm.value)

            ForEach(circuits) { circuit in
                // Una columna sintética agrupa intentos sin recorrido
                // asignado. Pintar su identificador inventado —«U00»— la haría
                // pasar por un recorrido que no existe.
                Text(circuit.displayLabel)
                    .font(.body(size: 12, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(Color.muted)
                    .italic(circuit.isSynthetic)
                    .lineLimit(1)
                    .frame(minWidth: cellMinWidth, alignment: .center)
                    .padding(.horizontal, Theme.spacing.xs.value)
            }
        }
        .padding(.vertical, Theme.spacing.md.value)
        .background(Color.paperElevated)
    }

    // MARK: - Filas

    private func dataRow(_ row: ResultadoRow, circuits: [MatrixCircuitDTO]) -> some View {
        HStack(spacing: 0) {
            // Todas las posiciones se pintan igual. Colorear la insignia por
            // «dentro/fuera» dibujaría una línea de corte en pantalla, y el
            // sistema no adjudica plazas ni emite veredicto. RGPD art. 22.
            Text(row.position.map(String.init) ?? "—")
                .font(.body(size: 14, weight: .bold, relativeTo: .subheadline))
                .foregroundStyle(row.hasNotDriven ? Color.muted : Color.ink)
                .frame(width: positionColumnWidth, alignment: .center)

            nameCell(row)

            scoreCell(row)

            ForEach(circuits) { circuit in
                circuitCell(
                    row.byCircuit[circuit.id],
                    candidateName: row.name,
                    circuitLabel: circuit.displayLabel
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func nameCell(_ row: ResultadoRow) -> some View {
        let label = VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(row.name)
                    .font(.bodyText)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if row.tied {
                    Text("empate")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
            }
            if let composition = row.composition,
               composition.hasPendingRoutes, !composition.isGlobalBest {
                // De dónde sale la nota de esta fila. Descriptivo, nunca
                // prescriptivo: «5 de 10» es un hecho; «le faltan 5» insinúa un
                // deber y un resultado.
                Text("\(composition.completedRequired) de \(composition.totalRequired) exigidos")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            } else if let plaza = row.plaza {
                Text("Plaza \(plaza)")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
        }
        .frame(width: nameColumnWidth, alignment: .leading)
        .padding(.horizontal, Theme.spacing.sm.value)

        if !row.candidateId.hasPrefix("anon-") {
            NavigationLink(value: ResultadoStudentRoute(studentId: row.candidateId)) {
                label
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityRowLabel(row))
        } else {
            label.accessibilityLabel(accessibilityRowLabel(row))
        }
    }

    @ViewBuilder
    private func scoreCell(_ row: ResultadoRow) -> some View {
        // El 0,0 que acompaña a un ausente no es una nota baja: nadie la midió.
        // Pintarlo afirmaría, sobre una persona en una oposición pública, que
        // se evaluó su conducción y salió mal.
        Text(row.score.map(ScoreFormat.aggregate) ?? "—")
            .font(.bodyEmphasis)
            .foregroundStyle(row.score == nil ? Color.muted : Color.ink)
            .frame(width: scoreColumnWidth, alignment: .trailing)
            .padding(.trailing, Theme.spacing.sm.value)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func circuitCell(
        _ cell: MatrixScoreDTO?,
        candidateName: String,
        circuitLabel: String
    ) -> some View {
        let content = Text(cell?.score.map(ScoreFormat.attempt) ?? "—")
            .font(.bodyText)
            .foregroundStyle(cell?.score == nil ? Color.muted : Color.ink)
            .frame(minWidth: cellMinWidth, alignment: .center)
            .padding(.horizontal, Theme.spacing.xs.value)
            .padding(.vertical, Theme.spacing.md.value)

        if let attemptId = cell?.attemptId, cell?.score != nil {
            NavigationLink(value: ResultadoAttemptRoute(attemptId: attemptId)) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(candidateName), \(circuitLabel), nota \(cell?.score.map(ScoreFormat.attempt) ?? "—")")
        } else {
            content
                .accessibilityLabel("\(candidateName), \(circuitLabel), sin conducir")
        }
    }

    // MARK: - Secciones y pie

    /// Los inscritos que no han conducido van aparte y rotulados.
    ///
    /// Mezclarlos con los demás los colocaría en un orden de méritos del que no
    /// forman parte, y una fila de guiones sin encabezado se lee como un fallo
    /// de carga.
    private func notPresentedHeader(count: Int) -> some View {
        Text(count == 1 ? "Sin recorridos conducidos" : "Sin recorridos conducidos (\(count))")
            .font(.body(size: 12, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(Color.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.top, Theme.spacing.lg.value)
            .padding(.bottom, Theme.spacing.sm.value)
    }

    /// Cómo leer la tabla.
    ///
    /// Sin esto, una fila con cinco notas entre 8,5 y 10 y una nota oficial de
    /// 4,75 parece un error de cálculo. La columna vacía es el dato, no un
    /// hueco.
    @ViewBuilder
    private func footnote(_ data: ResultadosData) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
            Text("La nota es la media del mejor intento de cada recorrido exigido. Los recorridos exigidos y no conducidos computan como cero.")
            if data.hasUndrivenRequiredColumn {
                Text("Las columnas sin ninguna nota corresponden a recorridos que la convocatoria exige y que todavía no ha conducido nadie.")
            }
            Text("La asignación de plaza la decide CMadrid al cierre de la convocatoria.")
        }
        .font(.metaCaption)
        .foregroundStyle(Color.muted)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.spacing.base.value)
        .padding(.vertical, Theme.spacing.md.value)
    }

    private func accessibilityRowLabel(_ row: ResultadoRow) -> String {
        var parts = [row.position.map { "Puesto \($0)" } ?? "Sin puesto", row.name]
        if row.tied { parts.append("empate") }
        if let score = row.score {
            parts.append("nota \(ScoreFormat.aggregate(score))")
        } else {
            parts.append("sin recorridos conducidos")
        }
        if let composition = row.composition,
           composition.hasPendingRoutes, !composition.isGlobalBest {
            parts.append("\(composition.completedRequired) de \(composition.totalRequired) recorridos exigidos")
            if let average = composition.scoreOfCompleted {
                parts.append("media de lo conducido \(ScoreFormat.aggregate(average))")
            }
        }
        return parts.joined(separator: ", ")
    }
}

import SwiftUI

@MainActor
@Observable
final class AttemptDetailViewModel {
    enum State {
        case loading
        case loaded(AttemptDetailDTO)
        case notFound
        case error(String)
    }

    var state: State = .loading

    /// Refresco en curso SOBRE datos ya visibles.
    var isRefreshing = false

    /// El fallo del último refresco, cuando había datos que conservar.
    var refreshError: String?

    private let api: TrainingAPI

    /// La costura que el resto de los view models ya tenía. Sin ella este
    /// arreglo no se podía probar, que es la razón por la que fue el último en
    /// hacerse.
    init(api: TrainingAPI = APIClient.shared) {
        self.api = api
    }

    func load(attemptId: String, auth: AuthSession) async {
        // La última pantalla que seguía vaciándose a un spinner en cada
        // recarga. Se llega a ella y se tira hacia abajo para ver si ya llegó
        // la nota: con cobertura mala, el intento que se estaba leyendo
        // desaparecía y volvía como error.
        let teniaDatos: Bool
        if case .loaded = state { teniaDatos = true } else { teniaDatos = false }

        if teniaDatos { isRefreshing = true } else { state = .loading }
        defer { isRefreshing = false }

        do {
            let attempt = try await auth.authorized { [api] token in
                try await api.attempt(id: attemptId, accessToken: token)
            }
            state = .loaded(attempt)
            refreshError = nil
        } catch let error as APIError where error.notFoundReason != nil {
            // Una respuesta, no una ausencia: si el intento ya no consta, no
            // se conserva el que había.
            state = .notFound
        } catch {
            let mensaje = (error as? APIError)?.userMessage ?? error.localizedDescription
            if teniaDatos {
                refreshError = "\(mensaje) Se muestra el último dato consultado."
            } else {
                state = .error(mensaje)
            }
        }
    }
}

struct AttemptDetailView: View {
    let attemptId: String

    /// Nombre de la convocatoria del intento. El contrato solo envía el
    /// identificador, así que lo aporta quien navega hasta aquí y lo conoce.
    var convocatoriaName: String?

    /// Si la nota de esta convocatoria es provisional o definitiva.
    ///
    /// Como el nombre, lo aporta quien navega: el contrato del intento no
    /// envía el estado de la convocatoria. Por defecto `.unknown`, que no
    /// afirma nada — los caminos del instructor entran así.
    var finality: GradeFinality = .unknown

    /// Cuándo se cerró la convocatoria, cuando se sabe. Solo acompaña a la
    /// aclaración de la nota.
    var convocatoriaClosedAt: String?

    /// Cuándo fue el intento.
    ///
    /// `AttemptDetailDTO` no la trae —el contrato del detalle no la envía— pero
    /// el resumen de la lista sí, y quien navega la tiene en la mano. Sin ella
    /// dos vueltas al mismo recorrido son indistinguibles una vez abiertas.
    var createdAt: String?

    @Environment(AuthSession.self) private var auth
    @State private var viewModel = AttemptDetailViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: Theme.spacing.md.value) {
                    ProgressView().tint(Color.brand)
                    Text("Cargando intento…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground()
            case .notFound:
                ContentUnavailableView(
                    "Intento no encontrado",
                    systemImage: "questionmark.folder",
                    description: Text("No dispone de acceso a este intento, o el intento no existe.")
                )
            case .loaded(let attempt):
                AttemptDetailContent(
                    convocatoriaName: convocatoriaName,
                    finality: finality,
                    convocatoriaClosedAt: convocatoriaClosedAt,
                    createdAt: createdAt,
                    attempt: attempt,
                    refreshError: viewModel.refreshError,
                    onRetry: { Task { await load() } }
                )
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
        .navigationTitle("Intento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .loaded(let attempt) = viewModel.state {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText(attempt)) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.brand)
                    }
                    .accessibilityLabel("Compartir resumen del intento")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func shareText(_ attempt: AttemptDetailDTO) -> String {
        AttemptShareText.build(
            candidateName: attempt.candidate?.name,
            routeLabel: attempt.route?.label ?? attempt.route?.id,
            score: attempt.score,
            quality: attempt.quality,
            createdAt: createdAt
        )
    }

    private func load() async {
        await viewModel.load(attemptId: attemptId, auth: auth)
    }
}

private struct AttemptStudentRoute: Hashable {
    let studentId: String
}

/// Destino del mapa del intento.
struct AttemptMapRoute: Hashable {
    let attemptId: String
}

private struct AttemptDetailContent: View {
    @Environment(AuthSession.self) private var auth

    /// Nombre de la convocatoria, resuelto por quien navega hasta aquí. El
    /// contrato solo envía el identificador.
    var convocatoriaName: String?

    var finality: GradeFinality = .unknown
    var convocatoriaClosedAt: String?
    var createdAt: String?

    let attempt: AttemptDetailDTO

    /// Por qué lo que se ve puede no ser lo último. Conservar el dato en
    /// silencio sería peor que vaciar la pantalla: quien no sabe que su
    /// refresco falló cree que está mirando lo de ahora.
    var refreshError: String?
    var onRetry: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing.lg.value) {
                summaryCard
                if !attempt.scoreBreakdown.isEmpty {
                    breakdownCard
                }
                // El recorrido en el mapa. Va aquí, sobre la conducción:
                // «dónde pasó» ordena la lectura de «qué pasó».
                NavigationLink(value: AttemptMapRoute(attemptId: attempt.id ?? "")) {
                    HStack(spacing: Theme.spacing.sm.value) {
                        Image(systemName: "map.fill")
                            .foregroundStyle(Color.brand)
                        Text("Ver el recorrido en el mapa")
                            .font(.bodyEmphasis)
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.muted)
                    }
                    .padding(Theme.spacing.base.value)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                        .fill(Color.paperElevated)
                )
                .themedShadow(.small)
                .accessibilityIdentifier("attempt.openMap")

                // Los cuatro bloques de conducción: lo que contesta «en qué he
                // fallado» cuando falta la mitad de estabilidad.
                //
                // Fuera del `if` de los eventos a propósito: un intento puede
                // no tener ni un evento y tener la conducción entera, que es
                // justo el caso en el que esta sección es la única respuesta.
                // La sección decide sola si hay algo que pintar.
                DrivingBlocksSection(attempt: attempt)

                if !attempt.events.isEmpty {
                    eventsCard
                }

                refreshFooter
                legalFooter
            }
            .readableWidth()
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationDestination(for: AttemptStudentRoute.self) { route in
            StudentProfileView(studentId: route.studentId)
        }
        .navigationDestination(for: AttemptMapRoute.self) { route in
            AttemptMapView(attemptId: route.attemptId)
        }
    }

    @ViewBuilder
    private var refreshFooter: some View {
        if let refreshError {
            HStack(alignment: .top, spacing: Theme.spacing.sm.value) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(Color.warning)
                    .accessibilityHidden(true)
                Text(refreshError)
                    .font(.metaCaption)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Reintentar", action: onRetry)
                    .font(.metaCaption)
                    .foregroundStyle(Color.brand)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("attempt.retryRefresh")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(refreshError)
        }
    }

    /// Qué vale esta pantalla legalmente.
    ///
    /// El portal lo dice en todas sus páginas, esta incluida; la app no lo
    /// decía en ninguna. Y es la pantalla que más se fotografía y se pasa:
    /// justo donde la frase tiene que estar.
    ///
    /// Con la finalidad desconocida no se pinta nada. Un camino que no sabe el
    /// estado de la convocatoria no puede afirmar que el resultado es
    /// provisional, igual que no puede afirmar que es definitivo.
    @ViewBuilder
    private var legalFooter: some View {
        if let note = finality.note(closedAt: convocatoriaClosedAt) {
            Text(note)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("attempt.legalNotice")
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md.value) {
            // La nota, y cuando no la hay, que no la hay.
            //
            // Antes el `if let` envolvía el bloque entero, así que un intento
            // sin nota abría en una tarjeta que empezaba en otro sitio: sin
            // cifra, sin explicación y sin insignia de calidad, porque la
            // insignia vivía dentro del mismo `if` y se iba con él.
            let presentation = AttemptScorePresentation(score: attempt.score)
            HStack(alignment: .firstTextBaseline, spacing: Theme.spacing.sm.value) {
                Text(presentation.heroText)
                    .font(presentation.showsScale
                          ? .display(size: 56, weight: .bold, italic: false, relativeTo: .largeTitle)
                          : .cardTitle)
                    .foregroundStyle(presentation.showsScale ? Color.ink : Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if presentation.showsScale {
                    Text("/10")
                        .font(.cardTitle)
                        .foregroundStyle(Color.muted)
                }
                Spacer()
                // Fuera del condicional: la calidad del dato es un hecho del
                // intento, no de su nota, y sin nota es cuando más informa.
                if let quality = attempt.quality {
                    StatusBadge(text: quality.label, kind: quality.badgeKind)
                }
            }
            if let detail = presentation.heroDetail {
                Text(detail)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()

            // Un intento de prácticas se puntúa y se ve, pero no ordena la
            // oposición. Decirlo aquí evita que alguien no entienda por qué su
            // 10 no le movió la nota.
            if attempt.route?.isPractice == true {
                Text("Recorrido de prácticas: puntúa, pero no interviene en la nota oficial.")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: Theme.spacing.sm.value) {
                // Primero la fecha: es lo que sitúa el intento. Sin ella el
                // resumen empezaba por el recorrido, que es justamente el dato
                // que comparten todas las vueltas indistinguibles entre sí.
                if let fecha = APIDate.shortDateTime(createdAt) {
                    summaryRow(label: "Fecha", value: fecha)
                }
                if let cand = attempt.candidate {
                    // Desde el ranking y la matriz se llega al perfil del
                    // aspirante; entrando por una alerta de Webfleet no había
                    // salida hacia él.
                    if let candidateId = cand.id, !candidateId.isEmpty, auth.user?.isAdminLike == true {
                        NavigationLink(value: AttemptStudentRoute(studentId: candidateId)) {
                            summaryRow(
                                label: "Aspirante",
                                value: cand.name ?? "—",
                                showsDisclosure: true
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        summaryRow(label: "Aspirante", value: cand.name ?? "—")
                    }
                }
                if let route = attempt.route {
                    summaryRow(label: "Recorrido", value: route.displayName ?? "—")
                    if route.isPractice == true {
                        summaryRow(label: "Tipo", value: "Prácticas")
                    }
                }
                // El contrato solo trae el identificador, así que el nombre lo
                // aporta quien navega hasta aquí. Cuando no lo sabe, se degrada
                // en vez de desaparecer: al instructor le sirve una referencia
                // corta para cotejar, y al aspirante no se le enseña un
                // identificador de base de datos que no significa nada para él.
                if let convocatoriaName {
                    summaryRow(label: "Convocatoria", value: convocatoriaName)
                } else if
                    auth.user?.isAdminLike == true,
                    let reference = attempt.convocatoriaId?.prefix(8),
                    !reference.isEmpty
                {
                    summaryRow(label: "Convocatoria", value: "Ref. \(reference)")
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func summaryRow(
        label: String,
        value: String,
        showsDisclosure: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .font(.bodyText)
                .foregroundStyle(Color.muted)
            Spacer()
            Text(value)
                .font(.bodyEmphasis)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.trailing)
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.muted)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    /// Desglose de la nota por componente.
    ///
    /// Las filas se identifican por índice: `family` es una etiqueta de display
    /// y dos filas del mismo componente pueden compartirla.
    @ViewBuilder
    private var breakdownCard: some View {
        // Un intento de entrada manual llega sin desglose. Mejor no enseñar la
        // tarjeta que enseñar un encabezado sobre nada.
        if !attempt.scoreBreakdown.isEmpty {
            VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
                Text("Desglose")
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                VStack(spacing: 0) {
                    ForEach(Array(attempt.scoreBreakdown.enumerated()), id: \.offset) { index, item in
                        breakdownRow(item)
                        if index < attempt.scoreBreakdown.count - 1 {
                            Divider()
                        }
                    }
                }
                // La suma de las filas NO reproduce la nota, y no va a hacerlo:
                // la publicada lleva un decimal y las filas están redondeadas a
                // dos. Sin decirlo, un aspirante suma 8,45, lee 8,5 y concluye
                // que hay un error en su calificación.
                Text(breakdownRoundingNote)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    /// Por qué las filas no suman la nota de arriba.
    ///
    /// Cuando el contrato envía `scoreRaw` se nombra, porque es el número al
    /// que sí se acercan las filas (±0,01 por fila) y es el que cierra la
    /// cuenta a quien la hace. Sin él, se dice la regla sin inventarse cifras.
    private var breakdownRoundingNote: String {
        let base = "Las filas están redondeadas a dos decimales, así que su suma no coincide exactamente con la nota."
        guard let raw = attempt.scoreRaw, let published = attempt.score,
              ScoreFormat.aggregate(raw) != ScoreFormat.attempt(published) else {
            return base
        }
        return base + " Sin redondear la nota es \(ScoreFormat.aggregate(raw)); publicada lleva un decimal."
    }

    @ViewBuilder
    private func breakdownRow(_ item: AttemptScoreFamilyDTO) -> some View {
        HStack {
            Text(item.family ?? "—")
                .font(.bodyText)
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            switch item.presentation {
            case let .measured(obtained, max):
                Text("\(formatScore(obtained)) / \(formatScore(max))")
                    .font(.bodyEmphasis)
                    .foregroundStyle(Color.ink)
            case .notMeasured, .missingData:
                // Sin números —«— / 0» se leía como un cero que el aspirante no
                // sacó— y ahora con el motivo, que el contrato ya envía.
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.presentation.label)
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                    if let detail = item.unavailabilityDetail {
                        Text(detail)
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, Theme.spacing.sm.value)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Eventos")
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            VStack(spacing: 0) {
                ForEach(attempt.events) { ev in
                    VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
                        HStack {
                            Text(ev.type ?? "—")
                                .font(.bodyEmphasis)
                                .foregroundStyle(Color.ink)
                            // Con qué gravedad se calificó. El contrato la
                            // mandaba desde el principio y la ficha no la
                            // enseñaba: es lo que permite entender una
                            // deducción y nombrarla al pedir revisión.
                            if let gravity = ev.gravity {
                                StatusBadge(text: gravity.label, kind: ev.gravityBadgeKind)
                            }
                            Spacer()
                            if let ts = APIDate.displayInstant(ev.timestamp) {
                                Text(ts)
                                    .font(.metaCaption)
                                    .foregroundStyle(Color.muted)
                            }
                        }
                        if let descr = ev.description {
                            Text(descr)
                                .font(.metaCaption)
                                .foregroundStyle(Color.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // De dónde salió y con qué intensidad lo registró el
                        // sensor. Sin esto, todos los eventos se leen igual de
                        // graves y sin procedencia.
                        // La intensidad vuelve, ahora que el contrato dice
                        // cuáles descontaron de verdad.
                        //
                        // Sin ese dato no se podía pintar: hay eventos
                        // informativos por diseño —el badén— que llegan con
                        // intensidad alta y no restan nada. Mostrarlos como
                        // incidencias que penalizaron le atribuía al aspirante
                        // algo que no ocurrió.
                        HStack(spacing: Theme.spacing.sm.value) {
                            if let source = ev.sourceLabel {
                                Label(source, systemImage: "dot.radiowaves.left.and.right")
                                    .font(.metaCaption)
                                    .foregroundStyle(Color.muted)
                            }
                            if ev.didPenalise, let intensity = ev.intensity {
                                Text("Intensidad \(intensity.rawValue.lowercased())")
                                    .font(.metaCaption)
                                    .foregroundStyle(Color.muted)
                            }
                        }

                        // Y si no descontó, se dice. Un evento en la lista sin
                        // más contexto se lee como algo que restó.
                        if !ev.didPenalise {
                            Text(ev.noPenaltyLabel)
                                .font(.metaCaption)
                                .foregroundStyle(Color.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, Theme.spacing.sm.value)
                    if ev.id != attempt.events.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Dos decimales: el peso efectivo que el backend fija por recorrido los
    /// usa, y redondear a uno mostraba un máximo que no era el configurado.
    private func formatScore(_ value: Double) -> String {
        ScoreFormat.component(value)
    }

}

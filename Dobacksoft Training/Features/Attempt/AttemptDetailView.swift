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

    func load(attemptId: String, auth: AuthSession) async {
        state = .loading
        do {
            let attempt = try await auth.authorized { token in
                try await APIClient.shared.attempt(id: attemptId, accessToken: token)
            }
            state = .loaded(attempt)
        } catch let error as APIError where error.notFoundReason != nil {
            state = .notFound
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

struct AttemptDetailView: View {
    let attemptId: String

    /// Nombre de la convocatoria del intento. El contrato solo envía el
    /// identificador, así que lo aporta quien navega hasta aquí y lo conoce.
    var convocatoriaName: String?

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
                AttemptDetailContent(convocatoriaName: convocatoriaName, attempt: attempt)
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
        var lines: [String] = ["Intento Training · CMadrid"]
        if let candName = attempt.candidate?.name { lines.append("Alumno: \(candName)") }
        if let routeLabel = attempt.route?.label ?? attempt.route?.id {
            lines.append("Ruta: \(routeLabel)")
        }
        if let s = attempt.score {
            lines.append("Nota: \(ScoreFormat.attempt(s))/10")
        }
        if let dq = attempt.dataQuality {
            lines.append("Calidad: \(dq)")
        }
        return lines.joined(separator: "\n")
    }

    private func load() async {
        await viewModel.load(attemptId: attemptId, auth: auth)
    }
}

private struct AttemptStudentRoute: Hashable {
    let studentId: String
}

private struct AttemptDetailContent: View {
    @Environment(AuthSession.self) private var auth

    /// Nombre de la convocatoria, resuelto por quien navega hasta aquí. El
    /// contrato solo envía el identificador.
    var convocatoriaName: String?

    let attempt: AttemptDetailDTO

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing.lg.value) {
                summaryCard
                if !attempt.scoreBreakdown.isEmpty {
                    breakdownCard
                }
                if !attempt.events.isEmpty {
                    eventsCard
                }
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationDestination(for: AttemptStudentRoute.self) { route in
            StudentProfileView(studentId: route.studentId)
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md.value) {
            // Hero score
            if let s = attempt.score {
                HStack(alignment: .firstTextBaseline, spacing: Theme.spacing.sm.value) {
                    Text(ScoreFormat.attempt(s))
                        .font(.display(size: 56, weight: .bold, italic: false, relativeTo: .largeTitle))
                        .foregroundStyle(Color.ink)
                    Text("/10")
                        .font(.cardTitle)
                        .foregroundStyle(Color.muted)
                    Spacer()
                    if let quality = attempt.quality {
                        StatusBadge(text: quality.label, kind: quality.badgeKind)
                    }
                }
                Divider()
            }

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
                if let cand = attempt.candidate {
                    // Desde el ranking y la matriz se llega al perfil del
                    // aspirante; entrando por una alerta de Webfleet no había
                    // salida hacia él.
                    if let candidateId = cand.id, !candidateId.isEmpty, auth.user?.isAdminLike == true {
                        NavigationLink(value: AttemptStudentRoute(studentId: candidateId)) {
                            summaryRow(
                                label: "Alumno",
                                value: cand.name ?? "—",
                                showsDisclosure: true
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        summaryRow(label: "Alumno", value: cand.name ?? "—")
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

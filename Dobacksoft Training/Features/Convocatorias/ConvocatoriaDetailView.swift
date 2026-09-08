import SwiftUI

struct ConvocatoriaDetailView: View {
    let convocatoria: ConvocatoriaSummaryDTO
    @Environment(AuthSession.self) private var auth

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing.lg.value) {
                headerCard
                if let descr = convocatoria.description, !descr.isEmpty {
                    descriptionCard(descr)
                }
                actionsList
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationTitle(convocatoria.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.brand)
                }
                .accessibilityLabel("Compartir convocatoria")
            }
        }
    }

    private var shareText: String {
        var lines: [String] = ["Convocatoria Training · CMadrid", convocatoria.name]
        if let s = convocatoria.status { lines.append("Estado: \(s)") }
        lines.append("Aspirantes: \(convocatoria.totalCandidates)")
        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md.value) {
            HStack {
                Text(convocatoria.name)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(3)
                Spacer()
                if let status = convocatoria.status {
                    let estado = StatusVocabulary.convocatoria(status)
                    StatusBadge(text: estado.label, kind: estado.kind)
                }
            }

            HStack(spacing: Theme.spacing.lg.value) {
                metricBlock(value: "\(convocatoria.totalCandidates)", label: "Aspirantes")
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                // La fecha de cierre marca hasta cuándo puede cambiar la nota.
                // El portal web la pone en cabecera; aquí no se mostraba nunca,
                // pese a llegar en el contrato desde el principio.
                if let closed = APIDate.shortDate(convocatoria.closedAt) {
                    Text("Cierre · \(closed)")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                if let updated = APIDate.shortDateTime(convocatoria.updatedAt) {
                    Text("Actualizado · \(updated)")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private func metricBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.display(size: 28, weight: .bold, italic: false, relativeTo: .title))
                .foregroundStyle(Color.ink)
            Text(label)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
    }

    @ViewBuilder
    private func descriptionCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Descripción")
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            Text(text)
                .font(.bodyText)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var actionsList: some View {
        VStack(spacing: 0) {
            if auth.user?.isAdminLike == true {
                // Un solo destino, como en el portal (`/manager/resultados`).
                // Antes eran dos —«Ranking completo» y «Matriz de
                // puntuaciones»— para la misma pregunta, y separadas ninguna la
                // contestaba: el ranking decía quién iba delante sin decir de
                // qué está hecha la nota, y la matriz decía qué había conducido
                // cada uno sin decir en qué orden quedaban.
                actionRow(icon: "tablecells", label: "Resultados") {
                    ResultadosView(convocatoriaId: convocatoria.id, convocatoriaName: convocatoria.name)
                }
            }
            if auth.user?.isStudent == true {
                if auth.user?.isAdminLike == true {
                    Divider().padding(.leading, 52)
                }
                // La MISMA pantalla que la pestaña «Mi posición», no una
                // versión recortada.
                //
                // Este camino abría `StandingView`, que solo componía la
                // tarjeta de puesto y nota: el aspirante que llegaba por la
                // convocatoria NO veía sus intentos, y por la pestaña sí. El
                // mismo rótulo llevaba a dos pantallas distintas según el
                // camino, y en iPad éste es el único que existe, porque la
                // selección del sidebar no es automatizable.
                actionRow(icon: "trophy.fill", label: "Mi posición") {
                    MyConvocatoriaContentView(
                        convocatoriaId: convocatoria.id,
                        convocatoriaStatus: convocatoria.status,
                        convocatoriaName: convocatoria.name
                    )
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                .fill(Color.paperElevated)
        )
        .themedShadow(.small)
    }

    @ViewBuilder
    private func actionRow<Destination: View>(
        icon: String,
        label: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: Theme.spacing.md.value) {
                Image(systemName: icon)
                    .font(.body(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                Text(label)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Color.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.md.value)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Tocar para abrir")
    }

}

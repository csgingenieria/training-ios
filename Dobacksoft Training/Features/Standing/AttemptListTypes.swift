import SwiftUI

/// La lista de vueltas del aspirante: su modelo, su fila, y los tipos que
/// ordenan y filtran.
///
/// Los tres enums del final llevan una decisión que conviene no deshacer:
/// una vuelta **sin nota** va al final en los dos sentidos del orden por
/// nota, porque no es la peor — es la que todavía no se ha evaluado.
/// `AttemptSortAndFilterTests` lo sujeta.
@MainActor
@Observable
final class MyAttemptsViewModel {
    enum State {
        case loading
        case loaded([AttemptSummaryDTO])
        case empty
        case error(String)
    }

    var state: State = .loading

    func load(convocatoriaId: String, auth: AuthSession) async {
        state = .loading
        do {
            let items = try await auth.authorized { token in
                try await APIClient.shared.myAttempts(
                    convocatoriaId: convocatoriaId,
                    accessToken: token
                )
            }
            state = items.isEmpty ? .empty : .loaded(items)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

struct AttemptSummaryRow: View {
    let attempt: AttemptSummaryDTO

    /// El código delante del nombre, que es como se llama al recorrido en el
    /// parque. Sin recorrido, «Intento» — nunca una cadena vacía.
    private var routeTitle: String {
        let partes = [attempt.route?.codeIfDistinct, attempt.route?.displayName]
            .compactMap { $0 }
        return partes.isEmpty ? "Intento" : partes.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: Theme.spacing.md.value) {
            VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
                Text(routeTitle)
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                HStack(spacing: Theme.spacing.sm.value) {
                    if let date = APIDate.shortDateTime(attempt.createdAt) {
                        Text(date)
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                    }
                    if attempt.route?.isPractice == true {
                        // Ahora que el contrato manda la categoría, la app puede
                        // señalar qué intentos no cuentan para la nota. Antes
                        // solo podía poner una advertencia genérica en la lista.
                        StatusBadge(text: "Prácticas", kind: .neutral)
                    }
                    // La vuelta que HOY cuenta para la nota de este recorrido.
                    //
                    // El contrato lo manda en `isCurrentBest` desde el bloque
                    // C y el cliente lo decodificaba, lo tenía probado y no lo
                    // pintaba en ninguna parte. Sin él, quien tiene tres
                    // vueltas al mismo recorrido no puede saber cuál es la que
                    // le está puntuando.
                    if attempt.isCurrentBest == true {
                        StatusBadge(text: "Actual", kind: .brand)
                    }
                    if let quality = attempt.quality {
                        StatusBadge(text: quality.label, kind: quality.badgeKind)
                    }
                }
            }
            Spacer()
            scoreView
            DisclosureChevron()
        }
        .padding(.horizontal, Theme.spacing.base.value)
        .padding(.vertical, Theme.spacing.md.value)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tocar para ver detalle del intento")
    }

    @ViewBuilder
    private var scoreView: some View {
        // «Sin nota», no un guion. Es la regla que el widget lleva escrita
        // —«nunca un guion en lugar de una cifra»— y las palabras son las que
        // ya usa el filtro de intentos para este mismo caso.
        //
        // El guion además borraba una distinción que importa: «—» y «0,0»
        // significan lo contrario para quien se presenta a una oposición.
        Text(attempt.rowScoreText)
            .font(.body(size: attempt.hasScore ? 20 : 14, weight: .semibold, relativeTo: .title3))
            .foregroundStyle(attempt.hasScore ? Color.ink : Color.muted)
    }

}

// MARK: - Filtros locales para "Mis intentos"

enum AttemptSortMode: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst
    case scoreDescending
    case scoreAscending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newestFirst:     return "Más recientes"
        case .oldestFirst:     return "Más antiguos"
        case .scoreDescending: return "Mejor nota"
        case .scoreAscending:  return "Peor nota"
        }
    }

    var systemImage: String {
        switch self {
        case .newestFirst, .oldestFirst:           return "calendar"
        case .scoreDescending, .scoreAscending:    return "chart.bar"
        }
    }

    func apply(_ items: [AttemptSummaryDTO]) -> [AttemptSummaryDTO] {
        switch self {
        case .newestFirst:
            return items.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        case .oldestFirst:
            return items.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
        case .scoreDescending:
            return items.sorted { ($0.score ?? -1) > ($1.score ?? -1) }
        case .scoreAscending:
            return items.sorted { ($0.score ?? Double.infinity) < ($1.score ?? Double.infinity) }
        }
    }
}

nonisolated enum AttemptQualityFilter: String, CaseIterable, Identifiable {
    case all, high, medium, low

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:    return "Todas las calidades"
        case .high:   return "Calidad alta"
        case .medium: return "Calidad media"
        case .low:    return "Calidad baja"
        }
    }

    func matches(_ attempt: AttemptSummaryDTO) -> Bool {
        guard self != .all else { return true }
        let dq = (attempt.dataQuality ?? "").uppercased()
        switch self {
        case .all:    return true
        case .high:   return dq == "HIGH" || dq == "GOOD"
        case .medium: return dq == "MEDIUM" || dq == "OK"
        case .low:    return dq == "LOW" || dq == "BAD"
        }
    }
}

nonisolated enum AttemptScoreFilter: String, CaseIterable, Identifiable {
    case all, scored, unscored

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:      return "Con y sin nota"
        case .scored:   return "Con nota"
        case .unscored: return "Sin nota"
        }
    }

    func matches(_ attempt: AttemptSummaryDTO) -> Bool {
        switch self {
        case .all:      return true
        case .scored:   return attempt.score != nil
        case .unscored: return attempt.score == nil
        }
    }
}

import SwiftUI

/// El estado de «Mi posición», la pantalla de inicio del aspirante.
///
/// **Era el bloqueante de la auditoría.** El `load()` de la vista llenaba
/// `convocatorias` y no limpiaba nunca `errorMessage`, y el cuerpo miraba el
/// error ANTES que el contenido: después de un solo fallo pasajero, la
/// pantalla principal del aspirante mostraba «Error … Reintentar» para
/// siempre. Tocar Reintentar pedía los datos, los asignaba, y seguía pintando
/// el error. La única salida era matar la app.
///
/// El estado eran tres banderas independientes que podían contradecirse —
/// «cargando» y «error» y «aquí están sus datos» a la vez— y el orden de las
/// ramas decidía qué mentira ganaba. Aquí es un enum mutuamente excluyente, que
/// es lo que hace que la recuperación se pueda siquiera expresar.
@MainActor
@Observable
final class MyStandingTabViewModel {
    enum State: Equatable {
        case loading
        case loaded([ConvocatoriaSummaryDTO])
        case empty
        case error(String)
    }

    var state: State = .loading

    /// La fase, para animar el cambio sin animar cada cifra. Ver `ScreenPhase`.
    var phase: ScreenPhase {
        switch state {
        case .loading: .loading
        case .loaded:  .loaded
        case .empty:   .empty
        case .error:   .error
        }
    }

    /// La convocatoria elegida. La toca la vista desde el selector.
    var selectedId: String?

    var isRefreshing = false
    var refreshError: String?
    var lastUpdated: Date?

    private let api: TrainingAPI
    private let now: @Sendable () -> Date

    init(api: TrainingAPI = APIClient.shared, now: @escaping @Sendable () -> Date = Date.init) {
        self.api = api
        self.now = now
    }

    var convocatorias: [ConvocatoriaSummaryDTO] {
        if case .loaded(let items) = state { return items }
        return []
    }

    var selectedConvocatoria: ConvocatoriaSummaryDTO? {
        convocatorias.first { $0.id == selectedId }
    }

    func load(auth: AuthSession) async {
        let teniaDatos: Bool
        if case .loaded = state { teniaDatos = true } else { teniaDatos = false }

        if teniaDatos { isRefreshing = true } else { state = .loading }
        defer { isRefreshing = false }

        do {
            let items = try await auth.authorized { [api] token in
                try await api.myConvocatorias(accessToken: token)
            }
            state = items.isEmpty ? .empty : .loaded(items)
            reconcileSelection(with: items)
            // Lo que faltaba: el error se limpia al haber datos. Es la línea
            // cuya ausencia dejaba la pantalla muerta.
            refreshError = nil
            lastUpdated = now()
        } catch {
            // Una cancelación no es un fallo que contar: cambiar de
            // convocatoria a media carga cancela la anterior, y pintar su error
            // culparía al aspirante de algo que hizo la app.
            guard !Task.isCancelled, !error.isCancellation else { return }
            let mensaje = (error as? APIError)?.userMessage ?? error.localizedDescription
            if teniaDatos {
                refreshError = "\(mensaje) Se muestra el último dato consultado."
            } else {
                state = .error(mensaje)
            }
        }
    }

    /// La elección del aspirante sobrevive a una recarga.
    ///
    /// Reiniciarla en cada refresco le devolvería a la primera convocatoria
    /// cada vez que vuelve a la app. Pero una que ya no existe —una
    /// inscripción retirada— se sustituye, porque apuntar a algo que no está no
    /// pinta nada en absoluto.
    private func reconcileSelection(with items: [ConvocatoriaSummaryDTO]) {
        guard !items.isEmpty else {
            selectedId = nil
            return
        }
        if selectedId == nil || !items.contains(where: { $0.id == selectedId }) {
            selectedId = items.first?.id
        }
    }
}

import Foundation
import WidgetKit

/// Único punto de la app que escribe la instantánea de la vista rápida.
///
/// Centralizado a propósito: repartir escrituras por los ViewModels garantiza
/// que alguna ruta se olvide de actualizar —o peor, de borrar— y el widget
/// acabe mostrando el dato de otra persona.
@MainActor
final class SnapshotPublisher {
    static let shared = SnapshotPublisher()

    private let store: SnapshotStore
    private let defaults: UserDefaults

    private static let generationKey = "snapshot.generation"

    /// Preferencia del aspirante. Apagada de fábrica: el widget enseña datos
    /// personales en una pantalla que ve cualquiera que pase (RGPD art. 25.2,
    /// protección de datos por defecto).
    private static let enabledKey = "snapshot.quickViewEnabled"

    init(store: SnapshotStore = SnapshotStore(), defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    var isQuickViewEnabled: Bool {
        defaults.bool(forKey: Self.enabledKey)
    }

    func setQuickViewEnabled(_ enabled: Bool, republish: () -> StandingSnapshot.Content) {
        defaults.set(enabled, forKey: Self.enabledKey)
        publish(enabled ? republish() : .desactivado)
    }

    /// Publica un contenido. Respeta la preferencia: con la vista rápida
    /// apagada solo puede escribirse `.desactivado`.
    func publish(_ content: StandingSnapshot.Content) {
        let effective: StandingSnapshot.Content = isQuickViewEnabled ? content : .desactivado

        let generation = defaults.integer(forKey: Self.generationKey) + 1
        defaults.set(generation, forKey: Self.generationKey)

        let snapshot = StandingSnapshot(
            generation: generation,
            capturedAt: Date(),
            content: effective
        )

        guard store.write(snapshot) else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Borra la instantánea. Al cerrar sesión esto no es opcional: sin ello,
    /// quien ha salido sigue enseñando su puesto en la pantalla de inicio.
    func clear() {
        store.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Traduce el estado de la pantalla de posición a contenido publicable.
    ///
    /// Un error de carga **no** publica: un fallo de red pasajero no debe
    /// borrar un dato que sigue siendo el último bueno conocido.
    static func content(
        for state: StandingViewModel.State,
        convocatoriaName: String?,
        finality: GradeFinality
    ) -> StandingSnapshot.Content? {
        switch state {
        case let .loaded(standing):
            return .posicion(.init(
                convocatoriaName: convocatoriaName ?? "",
                position: standing.position,
                totalCandidates: standing.totalCandidates,
                score: standing.score,
                attemptsTotal: standing.attemptsTotal,
                finality: finality.snapshotValue
            ))
        case .notFound:
            return .sinPosicion(convocatoriaName: convocatoriaName ?? "")
        case .loading, .error:
            return nil
        }
    }
}

extension GradeFinality {
    var snapshotValue: StandingSnapshot.Finality {
        switch self {
        case .provisional: .provisional
        case .definitive:  .definitiva
        case .unknown:     .desconocida
        }
    }
}

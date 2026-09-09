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

    /// El almacén se construye dentro, no como valor por defecto del
    /// parámetro: esos se evalúan fuera del aislamiento de la clase y en
    /// aislamiento estricto eso es un error, no un aviso.
    init(store: SnapshotStore? = nil, defaults: UserDefaults = .standard) {
        self.store = store ?? SnapshotStore()
        self.defaults = defaults
    }

    var isQuickViewEnabled: Bool {
        defaults.bool(forKey: Self.enabledKey)
    }

    func setQuickViewEnabled(_ enabled: Bool, republish: () -> StandingSnapshot.Content) {
        defaults.set(enabled, forKey: Self.enabledKey)
        publish(enabled ? republish() : .desactivado)
    }

    private static let lastConvocatoriaKey = "snapshot.lastStandingConvocatoriaId"
    private static let lastConvocatoriaNameKey = "snapshot.lastStandingConvocatoriaName"

    /// La convocatoria de la última posición publicada.
    ///
    /// Se guarda para poder republicar al volver al frente sin obligar a nadie
    /// a entrar en «Mi posición»: hasta ahora esa era la ÚNICA pantalla que
    /// refrescaba las cifras del widget, así que envejecían aunque la persona
    /// abriera la app diez veces.
    var lastStandingConvocatoriaId: String? {
        get { defaults.string(forKey: Self.lastConvocatoriaKey) }
        set { defaults.set(newValue, forKey: Self.lastConvocatoriaKey) }
    }

    /// Y su nombre, porque `StandingDTO` no lo trae y el widget lo enseña.
    ///
    /// Es el nombre de una oposición pública, no un dato de nadie: es lo mismo
    /// que la instantánea ya guarda, y lo que no se guarda —ni aquí ni allí—
    /// es identificador de persona, correo, plaza ni cupo.
    var lastStandingConvocatoriaName: String? {
        get { defaults.string(forKey: Self.lastConvocatoriaNameKey) }
        set { defaults.set(newValue, forKey: Self.lastConvocatoriaNameKey) }
    }

    /// Si conviene republicar al volver al frente.
    ///
    /// Con la vista rápida apagada, **no**: pedir la posición para no
    /// publicarla es una petición que no sirve a nadie y toca datos que la
    /// persona ha dicho que no quiere en su pantalla de inicio.
    func shouldRefreshOnForeground() -> Bool {
        isQuickViewEnabled && lastStandingConvocatoriaId != nil
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
    /// Se borran al cerrar sesión con el resto: sin esto, el republicado al
    /// volver al frente pediría la posición de la convocatoria de otra persona
    /// con el token de la nueva.
    func clearLastStanding() {
        defaults.removeObject(forKey: Self.lastConvocatoriaKey)
        defaults.removeObject(forKey: Self.lastConvocatoriaNameKey)
    }

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
        case let .notFound(reason):
            // Sin inscripción no hay convocatoria de la que hablar; sin
            // posición todavía, sí. El widget no puede decir lo mismo en los
            // dos casos.
            return reason == .notEnrolled
                ? .sinConvocatoria
                : .sinPosicion(convocatoriaName: convocatoriaName ?? "")
        case .loading, .error:
            return nil
        case .cached:
            // **Tampoco publica**, y esta es la que más importa de las tres.
            //
            // El estado cacheado significa que no se pudo llegar a la red. El
            // widget ya tiene su propia última instantánea con SU fecha, y
            // republicar desde nuestra caché reescribiría ese `capturedAt` a
            // ahora: una cifra de anteayer pasaría a verse recién consultada en
            // la pantalla de inicio. Es exactamente la mentira que el diseño
            // del widget existe para evitar.
            return nil
        }
    }
}

extension GradeFinality {
    var snapshotValue: StandingSnapshot.Finality {
        switch self {
        case .provisional: .provisional
        // Dentro de la ventana de revocación la nota todavía puede cambiar, así
        // que para el widget cuenta como provisional. Perder ahí el matiz de
        // «pendiente de confirmación» es aceptable —el resumen no da para
        // explicarlo— pero llamarla definitiva no lo sería.
        case .pendingConfirmation: .provisional
        case .definitive:  .definitiva
        case .unknown:     .desconocida
        }
    }
}

import Foundation
import LocalAuthentication
import os

/// Quien sabe pedirle a alguien que demuestre ser el dueño del dispositivo.
///
/// Detrás de un protocolo para poder probar las decisiones sin biometría: un
/// simulador no tiene Face ID, así que sin esto la única prueba posible sería
/// mirar el código y creerse que hace lo que dice.
nonisolated protocol DeviceOwnerAuthenticator: Sendable {
    func capability() -> BiometryCapability
    func evaluate(reason: String) async throws -> Bool
}

/// La implementación real, sobre `LocalAuthentication`.
nonisolated struct SystemOwnerAuthenticator: DeviceOwnerAuthenticator {
    func capability() -> BiometryCapability {
        let context = LAContext()

        // Primero, si se puede evaluar SIQUIERA. Se pregunta por la política
        // que se va a usar: `.deviceOwnerAuthenticationWithBiometrics` diría
        // «no se puede» en un dispositivo con código y sin biometría inscrita,
        // y ahí sí se puede — solo cambia qué se pide.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            return .unavailable
        }

        // **Biometría DISPONIBLE no es biometría INSCRITA**, y `biometryType`
        // no distingue: describe el hardware. Un iPhone con Face ID y ninguna
        // cara registrada devuelve `.faceID` igual que uno configurado.
        //
        // Sin esta comprobación, `capability()` decía `.faceID` en un
        // dispositivo donde lo único que iba a funcionar era el código.
        // Encontrado ejecutando `SystemAuthenticatorProbe` contra un simulador
        // en ese estado exacto: `biometryType=.faceID`, `canEvaluate` de la
        // política completa `true`, y de la biométrica `false`. La
        // documentación no lo dice así de claro; el dispositivo sí.
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .passcodeOnly
        }

        switch context.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        default:       return .passcodeOnly
        }
    }

    func evaluate(reason: String) async throws -> Bool {
        // Un contexto nuevo por evaluación: uno reutilizado guarda el resultado
        // anterior y puede resolver sin preguntar nada.
        try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
}

/// El bloqueo opcional de la app.
///
/// Opt-in, apagado por defecto, y **nunca una puerta sin salida**: si la
/// comprobación no sale se ofrece reintentar y cerrar sesión, y si el
/// dispositivo pierde el código el ajuste se apaga solo diciéndolo. Las
/// decisiones viven en `AppLockRules`, que se prueba sin biometría.
@MainActor
@Observable
final class AppLock {
    enum State: Equatable {
        /// Se ve la app.
        case open

        /// Tapada, esperando que alguien pulse para autenticarse.
        case locked

        /// El diálogo del sistema está en pantalla.
        case asking
    }

    private(set) var state: State = .open

    /// El ajuste, en `UserDefaults` porque es una preferencia y no un secreto.
    /// Los tokens siguen en el Keychain, donde les toca.
    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: Self.key)
            if !isEnabled { state = .open }
        }
    }

    /// Lo que se le dice a quien intentó encenderlo y no se pudo.
    private(set) var enablementRefusal: String?

    private let authenticator: any DeviceOwnerAuthenticator
    private let defaults: UserDefaults
    private var leftForegroundAt: Date?
    private static let key = "appLock.enabled"
    private let log = Logger(subsystem: "com.dobacksoft.training", category: "AppLock")

    init(
        authenticator: any DeviceOwnerAuthenticator = SystemOwnerAuthenticator(),
        defaults: UserDefaults = .standard
    ) {
        self.authenticator = authenticator
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.key)
    }

    var capability: BiometryCapability { authenticator.capability() }

    /// Intenta encender el ajuste, y explica el rechazo si no se puede.
    ///
    /// Devuelve si quedó encendido, para que el `Toggle` pueda volverse atrás:
    /// un interruptor que se queda en «sí» tras un rechazo miente.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        guard enabled else {
            enablementRefusal = nil
            isEnabled = false
            return false
        }

        let capacidad = capability
        guard AppLockRules.mayEnable(capacidad) else {
            enablementRefusal = AppLockRules.enablementRefusal(capacidad)
            isEnabled = false
            return false
        }

        enablementRefusal = nil
        isEnabled = true
        return true
    }

    /// El arranque en frío y las vueltas al frente.
    func sceneBecameActive(authenticated: Bool, now: Date = .now) {
        // El dispositivo pudo perder el código después de encender el ajuste.
        // Mantenerlo encendido dejaría la app pidiendo algo que ya no se puede
        // dar: bloqueada y sin manera de abrirla.
        if isEnabled, AppLockRules.shouldTurnOffAfterLosingCapability(capability) {
            log.notice("El bloqueo se apaga: el dispositivo ya no puede evaluar la política.")
            isEnabled = false
            enablementRefusal = AppLockRules.turnedOffBecauseTheDeviceCannot
            state = .open
            return
        }

        guard AppLockRules.shouldAsk(
            enabled: isEnabled,
            authenticated: authenticated,
            leftForegroundAt: leftForegroundAt,
            now: now
        ) else { return }

        state = .locked
        Task { await authenticate() }
    }

    func sceneLeftForeground(now: Date = .now) {
        leftForegroundAt = now
    }

    /// La sesión se cerró: no hay nada que tapar.
    ///
    /// Y sin esto, la pantalla de acceso quedaría detrás del candado — que no
    /// protege ningún dato y solo impide entrar.
    func sessionEnded() {
        state = .open
        leftForegroundAt = nil
    }

    func authenticate() async {
        guard case .locked = state else { return }
        state = .asking

        do {
            let ok = try await authenticator.evaluate(reason: AppLockRules.reason)
            if ok {
                state = .open
                leftForegroundAt = nil
            } else {
                state = .locked
            }
        } catch {
            // El motivo del sistema NO se pinta: puede nombrar al dueño del
            // dispositivo. Se registra el código y se dice lo que hay que
            // hacer.
            log.notice("La autenticación no salió: \((error as NSError).code, privacy: .public)")
            state = .locked
        }
    }
}

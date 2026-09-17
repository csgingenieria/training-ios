import Testing
import Foundation

@testable import Dobacksoft_Training

/// The lock's behaviour, with the biometrics faked.
///
/// A simulator has no Face ID, so without a seam here the only possible check
/// would be reading the code and believing it does what it says — which is the
/// exact failure mode this repository has paid for repeatedly.
@MainActor
struct AppLockTests {
    /// A fake device owner: says what it can do, and answers as told.
    private final class Fake: DeviceOwnerAuthenticator, @unchecked Sendable {
        var can: BiometryCapability
        var answer: Result<Bool, Error>
        var evaluations = 0

        init(can: BiometryCapability = .faceID, answer: Result<Bool, Error> = .success(true)) {
            self.can = can
            self.answer = answer
        }

        func capability() -> BiometryCapability { can }

        func evaluate(reason: String) async throws -> Bool {
            evaluations += 1
            return try answer.get()
        }
    }

    private struct Denied: Error {}

    /// An isolated `UserDefaults` per test: the real one would carry the
    /// setting between tests and into the app.
    private func isolatedDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "AppLockTests.\(UUID().uuidString)")
        return suite ?? .standard
    }

    // MARK: - El bucle

    /// **El bucle que dejaba la app inaccesible.**
    ///
    /// Reportado en dispositivo real: al activar el desbloqueo con Face ID, la
    /// app pedía autenticación una y otra vez y nunca entraba.
    ///
    /// La causa no está en la biometría sino en el ciclo de la escena. El
    /// diálogo del sistema pone la app en `.inactive`, y al cerrarse la
    /// devuelve a `.active` — lo que dispara otra vez `sceneBecameActive`.
    /// Como el desbloqueo con éxito ponía `leftForegroundAt = nil`, el estado
    /// resultante era **indistinguible de un arranque en frío**, y la regla
    /// dice —con razón— que en un arranque en frío se pide siempre.
    ///
    /// Resultado: se desbloquea, el sistema devuelve el foco, se vuelve a
    /// pedir. Para siempre.
    @Test func unDesbloqueoCorrectoNoSeVuelveAPedirAlRecuperarElFoco() async {
        let fake = Fake(can: .faceID, answer: .success(true))
        let lock = AppLock(authenticator: fake, defaults: isolatedDefaults())
        lock.setEnabled(true)

        // Arranque en frío: se pide, y se concede.
        lock.sceneBecameActive(authenticated: true)
        await lock.authenticate()
        #expect(lock.state == .open)
        #expect(fake.evaluations == 1)

        // El diálogo se cierra y el sistema devuelve el foco. Esto NO es una
        // vuelta desde el fondo: nadie salió de la app.
        lock.sceneBecameActive(authenticated: true)

        #expect(lock.state == .open, "Se volvió a bloquear sin que nadie saliera de la app")
        #expect(fake.evaluations == 1, "Se pidió \(fake.evaluations) veces la autenticación")
    }

    /// El caso de control del anterior: **irse al fondo y volver pasada la
    /// gracia sí tiene que volver a pedir**. Sin esto, la prueba de arriba se
    /// contentaría con un bloqueo que no vuelve a pedir nunca, que es el
    /// defecto contrario y peor.
    @Test func volverDelFondoPasadaLaGraciaSiVuelveAPedir() async {
        let fake = Fake(can: .faceID, answer: .success(true))
        let lock = AppLock(authenticator: fake, defaults: isolatedDefaults())
        lock.setEnabled(true)

        let t0 = Date(timeIntervalSince1970: 1_757_000_000)
        lock.sceneBecameActive(authenticated: true, now: t0)
        await lock.authenticate()
        #expect(lock.state == .open)

        lock.sceneLeftForeground(now: t0)
        lock.sceneBecameActive(authenticated: true, now: t0.addingTimeInterval(AppLockRules.grace + 1))

        #expect(lock.state != .open, "Tras la gracia tenía que volver a pedir")
    }

    /// Y volver antes de la gracia no molesta: mirar una notificación y volver
    /// no puede obligar a autenticarse.
    @Test func volverDelFondoDentroDeLaGraciaNoPide() async {
        let fake = Fake(can: .faceID, answer: .success(true))
        let lock = AppLock(authenticator: fake, defaults: isolatedDefaults())
        lock.setEnabled(true)

        let t0 = Date(timeIntervalSince1970: 1_757_000_000)
        lock.sceneBecameActive(authenticated: true, now: t0)
        await lock.authenticate()

        lock.sceneLeftForeground(now: t0)
        lock.sceneBecameActive(authenticated: true, now: t0.addingTimeInterval(5))

        #expect(lock.state == .open)
        #expect(fake.evaluations == 1)
    }

    /// **El segundo bucle.** La primera corrección cubría el desbloqueo con
    /// éxito; quedaba el fallo. Falla o se cancela la autenticación, la tapa
    /// queda puesta con «Desbloquear» y «Cerrar sesión», el sistema devuelve
    /// el foco… y `sceneBecameActive` volvía a lanzar el diálogo, una y otra
    /// vez, dejando las dos salidas sin poder pulsarse. Encontrado por la
    /// revisión adversarial de la entrega, no por un usuario.
    @Test func unaAutenticacionFallidaYVueltaAlFocoNoRelanzaElDialogo() async {
        let fake = Fake(can: .faceID, answer: .failure(Denied()))
        let lock = AppLock(authenticator: fake, defaults: isolatedDefaults())
        lock.setEnabled(true)

        lock.sceneBecameActive(authenticated: true)
        await lock.authenticate()
        #expect(lock.state == .locked)
        #expect(fake.evaluations == 1)

        // El diálogo se cierra sin éxito y el sistema devuelve el foco.
        lock.sceneBecameActive(authenticated: true)

        #expect(lock.state == .locked, "Tenía que quedarse tapada, esperando a la persona")
        #expect(fake.evaluations == 1, "Se relanzó el diálogo \(fake.evaluations - 1) veces")
    }

    /// Y el control: con la tapa puesta, **la persona sí puede** pedir otro
    /// intento con el botón. Que no se relance solo no significa que no se
    /// pueda relanzar.
    @Test func conLaTapaPuestaElBotonSiPideOtroIntento() async {
        let fake = Fake(can: .faceID, answer: .failure(Denied()))
        let lock = AppLock(authenticator: fake, defaults: isolatedDefaults())
        lock.setEnabled(true)
        lock.sceneBecameActive(authenticated: true)
        await lock.authenticate()
        #expect(fake.evaluations == 1)

        fake.answer = .success(true)
        await lock.authenticate()   // lo que hace el botón «Desbloquear»

        #expect(lock.state == .open)
        #expect(fake.evaluations == 2)
    }

    // MARK: - El ajuste

    @Test func itIsOffByDefault() {
        let lock = AppLock(authenticator: Fake(), defaults: isolatedDefaults())
        #expect(lock.isEnabled == false)
        #expect(lock.state == .open)
    }

    /// **The switch refuses to turn on when it would protect nothing**, and
    /// says why. A switch left reading «on» after a refusal lies about what is
    /// guarding the screen.
    @Test func theSwitchRefusesWhenTheDeviceCannotEvaluate() {
        let lock = AppLock(authenticator: Fake(can: .unavailable), defaults: isolatedDefaults())

        let quedó = lock.setEnabled(true)

        #expect(quedó == false)
        #expect(lock.isEnabled == false, "el interruptor no puede quedarse en «sí»")
        #expect(lock.enablementRefusal?.contains("código") == true)
    }

    @Test func withAPasscodeButNoBiometryItTurnsOn() {
        let lock = AppLock(authenticator: Fake(can: .passcodeOnly), defaults: isolatedDefaults())
        #expect(lock.setEnabled(true))
        #expect(lock.isEnabled)
        #expect(lock.enablementRefusal == nil)
    }

    /// The setting survives a relaunch — that is the whole point of persisting
    /// it — and it is read from the same store it was written to.
    @Test func theSettingSurvivesARelaunch() {
        let store = isolatedDefaults()
        AppLock(authenticator: Fake(), defaults: store).setEnabled(true)

        let deNuevo = AppLock(authenticator: Fake(), defaults: store)
        #expect(deNuevo.isEnabled)
    }

    // MARK: - Cuándo tapa

    @Test func withTheSettingOffBecomingActiveNeverLocks() {
        let fake = Fake()
        let lock = AppLock(authenticator: fake, defaults: isolatedDefaults())

        lock.sceneBecameActive(authenticated: true)

        #expect(lock.state == .open)
        #expect(fake.evaluations == 0, "no se le pide nada a nadie")
    }

    /// **With no session it never locks.** A lock over the login screen guards
    /// no datum.
    @Test func withNoSessionItNeverLocks() {
        let fake = Fake()
        let lock = AppLock(authenticator: fake, defaults: isolatedDefaults())
        lock.setEnabled(true)

        lock.sceneBecameActive(authenticated: false)

        #expect(lock.state == .open)
        #expect(fake.evaluations == 0)
    }

    /// Signing out opens the screen and forgets the departure, so the login
    /// screen never ends up behind the lock.
    @Test func signingOutOpensTheScreen() {
        let lock = AppLock(authenticator: Fake(answer: .failure(Denied())), defaults: isolatedDefaults())
        lock.setEnabled(true)
        lock.sceneBecameActive(authenticated: true)

        lock.sessionEnded()

        #expect(lock.state == .open)
    }

    // MARK: - El caso que importa: no encerrar a nadie

    /// **The passcode removed after the setting was on turns the setting off**,
    /// instead of leaving a locked screen with no way to unlock it.
    ///
    /// This is the load-bearing test of the whole feature. Everything else is a
    /// convenience; this is the difference between a lock and a trap.
    @Test func losingThePasscodeOpensTheAppAndTurnsTheSettingOff() {
        let fake = Fake(can: .faceID)
        let lock = AppLock(authenticator: fake, defaults: isolatedDefaults())
        lock.setEnabled(true)
        #expect(lock.isEnabled)

        // El código desaparece de los Ajustes del dispositivo.
        fake.can = .unavailable
        lock.sceneBecameActive(authenticated: true)

        #expect(lock.state == .open, "no se queda tapada pidiendo algo que no se puede dar")
        #expect(lock.isEnabled == false, "y el ajuste se apaga solo")
        #expect(lock.enablementRefusal == AppLockRules.turnedOffBecauseTheDeviceCannot,
                "diciéndolo: un ajuste que se apaga en silencio no se entiende")
        #expect(fake.evaluations == 0, "y sin pedir una autenticación imposible")
    }

    /// Turning the setting off while the screen is covered opens it. Otherwise
    /// the only way out of the lock would be the lock itself.
    @Test func turningTheSettingOffOpensACoveredScreen() {
        let lock = AppLock(authenticator: Fake(answer: .failure(Denied())), defaults: isolatedDefaults())
        lock.setEnabled(true)
        lock.sceneBecameActive(authenticated: true)

        lock.setEnabled(false)

        #expect(lock.state == .open)
        #expect(lock.isEnabled == false)
    }
}

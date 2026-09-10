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

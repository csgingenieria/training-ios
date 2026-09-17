import Testing
import Foundation

@testable import Dobacksoft_Training

/// The optional lock, and the line it must never cross.
///
/// **An opt-in convenience cannot lock anyone out of their own account.** The
/// people using this are firefighter candidates with nobody to ask: an app that
/// refuses to open because of a setting they turned on a month ago is an
/// incident with the client, not a security measure. Every test here is about
/// that line rather than about biometrics.
struct AppLockRulesTests {
    private var t0: Date { Date(timeIntervalSince1970: 1_757_000_000) }

    // MARK: - Cuándo se pide

    /// Off by default, and off means never asked.
    @Test func withTheSettingOffItIsNeverAsked() {
        #expect(AppLockRules.shouldAsk(
            enabled: false, authenticated: true, alreadyResolved: false, leftForegroundAt: nil, now: t0
        ) == false)
    }

    /// **With no session it is never asked.** A lock over the login screen
    /// protects no datum: it only stops someone getting in.
    @Test func withNoSessionThereIsNothingToCover() {
        #expect(AppLockRules.shouldAsk(
            enabled: true, authenticated: false, alreadyResolved: false, leftForegroundAt: nil, now: t0
        ) == false)
        #expect(AppLockRules.shouldAsk(
            enabled: true, authenticated: false, alreadyResolved: false,
            leftForegroundAt: t0.addingTimeInterval(-3600), now: t0
        ) == false)
    }

    /// A cold start always asks: nothing is known about how the app got closed.
    @Test func aColdStartAlwaysAsks() {
        #expect(AppLockRules.shouldAsk(
            enabled: true, authenticated: true, alreadyResolved: false, leftForegroundAt: nil, now: t0
        ))
    }

    /// **Coming straight back does not ask.** Asking on every return makes the
    /// app unusable: glancing at a notification and coming back would demand an
    /// authentication.
    @Test func comingStraightBackDoesNotAsk() {
        #expect(AppLockRules.shouldAsk(
            enabled: true, authenticated: true, alreadyResolved: false,
            leftForegroundAt: t0, now: t0.addingTimeInterval(5)
        ) == false)
    }

    /// Past the grace it asks. The boundary is inclusive: at exactly the grace
    /// it asks — the doubt resolves towards asking, which costs a Face ID and
    /// not a leaked position.
    @Test func pastTheGraceItAsksAndTheBoundaryAsksToo() {
        let grace = AppLockRules.grace
        #expect(AppLockRules.shouldAsk(
            enabled: true, authenticated: true, alreadyResolved: false,
            leftForegroundAt: t0, now: t0.addingTimeInterval(grace)
        ))
        #expect(AppLockRules.shouldAsk(
            enabled: true, authenticated: true, alreadyResolved: false,
            leftForegroundAt: t0, now: t0.addingTimeInterval(grace - 0.001)
        ) == false)
    }

    /// **Ya resuelto: no se vuelve a pedir.**
    ///
    /// Es la regla que faltaba, y su ausencia dejaba la app inaccesible al
    /// activar el bloqueo: el diálogo del sistema devuelve el foco al cerrarse,
    /// eso cuenta como activación, y un desbloqueo correcto dejaba
    /// `leftForegroundAt` en `nil` — que la regla lee, con razón, como arranque
    /// en frío. Se desbloqueaba y se volvía a pedir, sin salida.
    @Test func alreadyResolvedDoesNotAskAgain() {
        #expect(AppLockRules.shouldAsk(
            enabled: true, authenticated: true, alreadyResolved: true,
            leftForegroundAt: nil, now: t0
        ) == false)
    }

    /// **Resuelto manda sobre el tiempo.** Quien limpia `alreadyResolved` es
    /// la salida al fondo, no el reloj: si por lo que sea llega `true` con una
    /// salida antigua, no se pide. Dejar que el tiempo lo anulara reabriría
    /// el bucle por otra puerta.
    ///
    /// La primera versión de esta prueba pasaba `alreadyResolved: false` y era
    /// un duplicado exacto de la de la gracia: decía una cosa y probaba otra.
    @Test func resolvedWinsOverElapsedTime() {
        #expect(AppLockRules.shouldAsk(
            enabled: true, authenticated: true, alreadyResolved: true,
            leftForegroundAt: t0, now: t0.addingTimeInterval(AppLockRules.grace + 3600)
        ) == false)
    }

    /// **A clock moved backwards asks.**
    ///
    /// A negative difference read as «just now» would turn the device clock
    /// into a way of never authenticating again. This is the opposite choice
    /// from `RefreshTicker`, and deliberately so: there, failing closed meant
    /// consuming the absence; here it means asking.
    @Test func aBackwardsClockAsks() {
        #expect(AppLockRules.shouldAsk(
            enabled: true, authenticated: true, alreadyResolved: false,
            leftForegroundAt: t0, now: t0.addingTimeInterval(-3600)
        ))
    }

    /// The grace is its own number, not the freshness one.
    ///
    /// `RefreshTicker.staleAfter` was right there at 300 s, and sharing it
    /// would tie «this figure is stale» to «the phone may have changed hands» —
    /// two decisions with nothing to do with each other, so that changing one
    /// would drag the other along.
    @Test func theGraceIsNotTheFreshnessNumber() {
        #expect(AppLockRules.grace == 60)
        #expect(AppLockRules.grace != RefreshTicker.staleAfter,
                "compartir la constante ataría dos decisiones distintas")
    }

    // MARK: - Cuándo se puede encender

    /// **Without a device passcode the setting cannot be turned on.**
    ///
    /// A switch that turns on and protects nothing is worse than not having
    /// one: it leaves someone believing their position and their grade sit
    /// behind a check that never happens.
    @Test func withoutAPasscodeTheSettingCannotBeTurnedOn() {
        #expect(AppLockRules.mayEnable(.unavailable) == false)
        let refusal = AppLockRules.enablementRefusal(.unavailable)
        #expect(refusal != nil)
        #expect(refusal?.contains("código") == true, "hay que decir QUÉ falta")
        #expect(refusal?.contains("Ajustes") == true, "y dónde se arregla")
    }

    /// **No biometry enrolled is not «cannot».** The policy used falls back to
    /// the device passcode, so a device with a passcode and no Face ID can hold
    /// the lock: only what is asked for changes.
    @Test func noBiometryEnrolledIsStillEnough() {
        #expect(AppLockRules.mayEnable(.passcodeOnly))
        #expect(AppLockRules.enablementRefusal(.passcodeOnly) == nil)
    }

    @Test func withBiometryItCanBeTurnedOn() {
        for capacidad in [BiometryCapability.faceID, .touchID] {
            #expect(AppLockRules.mayEnable(capacidad))
            #expect(AppLockRules.enablementRefusal(capacidad) == nil)
        }
    }

    // MARK: - Y cuando el dispositivo deja de poder

    /// **The passcode can be removed AFTER the setting is on.**
    ///
    /// Keeping it on then would leave the app demanding something that can no
    /// longer be given: a locked screen with no way to unlock it, over a
    /// convenience. It turns itself off and says so.
    @Test func losingThePasscodeTurnsTheSettingOffInsteadOfLockingPeopleOut() {
        #expect(AppLockRules.shouldTurnOffAfterLosingCapability(.unavailable))
        for capacidad in [BiometryCapability.faceID, .touchID, .passcodeOnly] {
            #expect(AppLockRules.shouldTurnOffAfterLosingCapability(capacidad) == false,
                    "\(capacidad) sí puede: no hay por qué apagarlo")
        }
        #expect(AppLockRules.turnedOffBecauseTheDeviceCannot.contains("código"))
    }

    // MARK: - Y si la comprobación no sale

    /// **Retry AND sign out.** Without the second, someone who cannot
    /// authenticate — a dirty sensor, a passcode they cannot recall right then
    /// — is shut inside a screen with nothing to press, their session inside
    /// and no way out.
    ///
    /// This asserts a constant, and that is only worth anything because
    /// `AppLockOverlay` now BUILDS its buttons from this list: drop `.signOut`
    /// here and the button disappears from the screen. It was written the
    /// other way round first — the buttons hard-coded, the constant read only
    /// by this test — and then the test could not have failed if someone
    /// deleted the exit.
    @Test func aFailedCheckAlwaysOffersAWayOut() {
        #expect(AppLockRules.exitsAfterFailure.contains(.signOut),
                "sin salida, el candado encierra a su propio dueño")
        #expect(AppLockRules.exitsAfterFailure.contains(.retry))
    }

    /// The system dialog's reason says WHAT it protects. That sentence is the
    /// only explanation on screen at that moment, so «autentíquese» would
    /// explain nothing.
    @Test func theSystemReasonSaysWhatItProtects() {
        #expect(AppLockRules.reason.contains("puesto"))
        #expect(AppLockRules.reason.contains("nota"))
    }

    /// And it never carries forbidden vocabulary, like every other string the
    /// candidate reads.
    @Test func theReasonRespectsTheForbiddenVocabulary() {
        let textos = [AppLockRules.reason, AppLockRules.turnedOffBecauseTheDeviceCannot]
            + [AppLockRules.enablementRefusal(.unavailable) ?? ""]
        for texto in textos {
            let bajo = texto.lowercased()
            for prohibida in ["apto", "aprobad", "suspens", "admitid", "excluid", "corte", "plaza"] {
                #expect(bajo.contains(prohibida) == false, "«\(texto)» dice «\(prohibida)»")
            }
        }
    }
}

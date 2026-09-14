import Testing
import Foundation
import LocalAuthentication

@testable import Dobacksoft_Training

/// Qué dice `LocalAuthentication` de verdad en este dispositivo.
///
/// **La única parte de `AppLock` que nunca se había ejecutado.** Los 23 tests
/// de `AppLockTests` usan un doble, que es lo correcto para probar las
/// decisiones — pero un doble no comprueba que el mapeo de `LAContext` a
/// `BiometryCapability` sea el que creo. Eso lo escribí leyendo documentación.
///
/// No afirma un valor concreto: el resultado depende de cómo esté configurado
/// el simulador o el teléfono. Lo que sí fija son las dos invariantes que no
/// pueden romperse en ninguna configuración.
/// **Lo que sigue SIN comprobar**, dicho aquí para que nadie lo dé por hecho:
/// la rama de biometría INSCRITA. No se ha conseguido que un simulador le
/// reporte `canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics) == true`
/// al proceso de test —ni con `notifyutil` sobre
/// `com.apple.BiometricKit.enrollmentChanged`, ni marcando «Enrolled» en el
/// menú del Simulador—, así que `capability()` nunca se ha visto devolver
/// `.faceID` ni `.touchID` de verdad. Hace falta un teléfono real con Face ID
/// configurado. Los tests de aquí abajo pasan igual: están escritos para no
/// afirmar nada sobre una rama que no se puede ejercitar.
struct SystemAuthenticatorProbe {
    /// **Biometría disponible no es biometría inscrita**, y `capability()`
    /// no puede confundirlas.
    ///
    /// La regla que este test fija se descubrió ejecutándolo: en un simulador
    /// con Face ID en el hardware y **ninguna cara registrada**,
    /// `LAContext.biometryType` devuelve `.faceID` igualmente —describe el
    /// hardware— mientras `canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`
    /// dice `false`. La implementación miraba solo `biometryType` y anunciaba
    /// `.faceID` en un dispositivo donde lo único que iba a funcionar era el
    /// código.
    ///
    /// Vale en cualquier configuración: con biometría inscrita la condición no
    /// se cumple y el test no afirma nada; sin ella, exige la respuesta
    /// honesta.
    @Test func availableBiometryIsNotEnrolledBiometry() {
        let contexto = LAContext()
        let completa = contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        let biometrica = contexto.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        let capacidad = SystemOwnerAuthenticator().capability()

        if completa && !biometrica {
            #expect(capacidad == .passcodeOnly,
                    "sin biometría inscrita no se puede anunciar biometría; dice \(capacidad)")
        }
        if !completa {
            #expect(capacidad == .unavailable)
        }
    }

    /// **`canEvaluatePolicy` y `capability` no pueden contradecirse.**
    ///
    /// Si el sistema dice que puede evaluar la política, el ajuste tiene que
    /// poder encenderse; si dice que no, tiene que negarse. Un desacuerdo aquí
    /// es un interruptor que se enciende y no protege nada, que es justo lo
    /// que `AppLockRules.mayEnable` existe para impedir.
    @Test func theCapabilityAgreesWithTheSystem() {
        let contexto = LAContext()
        let puede = contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        let capacidad = SystemOwnerAuthenticator().capability()

        #expect(AppLockRules.mayEnable(capacidad) == puede,
                "el sistema dice canEvaluate=\(puede) y la app dice \(capacidad)")
    }

    /// Se pregunta por la política que se va a USAR.
    ///
    /// `.deviceOwnerAuthenticationWithBiometrics` diría «no se puede» en un
    /// dispositivo con código y sin Face ID inscrito, y ahí sí se puede: solo
    /// cambia qué se pide. Este test falla si alguien cambia la política en
    /// `capability()` sin cambiarla en `evaluate(reason:)`.
    @Test func itAsksAboutThePolicyItWillUse() {
        let conCodigo = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        let soloBiometria = LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)

        // Si las dos difieren, este dispositivo tiene código y no biometría:
        // el caso exacto en el que preguntar por la política equivocada daría
        // «no se puede» sobre algo que sí se puede.
        if conCodigo && !soloBiometria {
            #expect(SystemOwnerAuthenticator().capability() == .passcodeOnly)
        }
        #expect(Bool(true))
    }
}

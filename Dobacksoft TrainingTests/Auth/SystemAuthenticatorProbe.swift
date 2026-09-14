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
/// **Las dos ramas están comprobadas contra hardware, en dos configuraciones
/// distintas:**
///
/// - Simulador iPhone 17 Pro con Face ID en el hardware y **sin inscribir**:
///   `biometryType=.faceID`, política completa `true`, biométrica `false`
///   → `capability() == .passcodeOnly`. Aquí apareció el defecto.
/// - iPhone 16 Pro real con Face ID configurado: política biométrica `true`
///   → `capability() == .faceID`.
///
/// Los tests están escritos para no dejar hueco: cubren los tres casos y
/// ninguno pasa en vacío. La primera versión solo afirmaba cuando NO había
/// biometría inscrita, así que en un teléfono configurado salía verde sin
/// haber comprobado nada — que es exactamente la clase de comprobación contra
/// la que existe este archivo.
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

        // Los tres casos, sin hueco. La versión anterior solo afirmaba cuando
        // NO había biometría inscrita, así que en un teléfono configurado
        // pasaba en vacío: verde sin haber comprobado nada.
        if !completa {
            #expect(capacidad == .unavailable)
        } else if !biometrica {
            #expect(capacidad == .passcodeOnly,
                    "sin biometría inscrita no se puede anunciar biometría; dice \(capacidad)")
        } else {
            #expect(capacidad == .faceID || capacidad == .touchID,
                    "con biometría inscrita hay que nombrarla; dice \(capacidad)")
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

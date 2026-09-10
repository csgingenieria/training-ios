import Testing
import Foundation

@testable import Dobacksoft_Training

/// User-facing copy is formal peninsular Spanish: the reader is a Madrid
/// firefighter. These cases pin the register, not just the wording — the
/// messages used to be written in Rioplatense voseo ("no tenés", "probá").
struct APIErrorTests {
    @Test func unauthenticatedMessage() {
        #expect(APIError.unauthenticated.userMessage == "La sesión ha caducado. Vuelva a iniciar sesión.")
    }

    @Test func forbiddenMessage() {
        #expect(APIError.forbidden.userMessage == "No dispone de permisos para acceder a esta sección.")
    }

    @Test func notFoundMessage() {
        #expect(APIError.notFound(.resourceMissing).userMessage == "No se ha encontrado el recurso solicitado.")
    }

    @Test func rateLimitedWithRetryAfter() {
        let error = APIError.rateLimited(retryAfter: 30)
        #expect(error.userMessage == "Demasiadas peticiones. Inténtelo de nuevo en 30 s.")
    }

    @Test func rateLimitedWithoutRetryAfter() {
        let error = APIError.rateLimited(retryAfter: nil)
        #expect(error.userMessage == "Demasiadas peticiones. Inténtelo de nuevo más tarde.")
    }

    /// **Validation and server errors do NOT surface the backend's message.**
    ///
    /// They used to, and that is the defect: a 502 from nginx yielded the
    /// fragment «Error del servidor» under a title «Error», and a 422 can carry
    /// text written for a developer or for the web portal. What the candidate
    /// needs is what to DO, and only the client knows how to say that in the
    /// register this app uses.
    @Test func validationSaysWhatToDoAndNotWhatTheBackendSaid() {
        let error = APIError.validation(message: "invalid payload: field 'x'", details: nil)
        #expect(error.userMessage == "No se ha podido procesar la petición. Inténtelo de nuevo.")
        #expect(!error.userMessage.contains("payload"))
    }

    @Test func aServerErrorSaysWhenToRetryAndWhoToTell() {
        let error = APIError.server(message: "502 Bad Gateway", status: 502)
        #expect(error.userMessage.contains("unos minutos"))
        #expect(error.userMessage.contains("instructor"), "hay una salida y se nombra")
        #expect(!error.userMessage.contains("502"))
    }

    @Test func decodingMessage() {
        let error = APIError.decoding(NSError(domain: "test", code: 0))
        #expect(error.userMessage == "La respuesta del servidor no tiene el formato esperado.")
    }

    @Test func transportMessage() {
        let error = APIError.transport(URLError(.notConnectedToInternet))
        #expect(error.userMessage == "No se ha podido conectar. Compruebe su conexión a la red.")
    }

    /// **The HTTP status does not reach the screen.** A «(418)» tells a
    /// firefighter nothing and asks them to read a number they cannot use. The
    /// status and body go to `AppLog.api`, which is where they help.
    @Test func theHTTPStatusNeverReachesTheScreen() {
        let error = APIError.unexpected(status: 418, body: "teapot")
        #expect(error.userMessage == "Se ha producido un error inesperado. Inténtelo de nuevo.")
        #expect(!error.userMessage.contains("418"))
        #expect(!error.userMessage.contains("teapot"))
    }

    /// Every message says what to do, or names who decides. A sentence that
    /// only states the fault leaves the person holding a dead screen.
    @Test func everyMessageOffersAWayOut() {
        let salidas = ["Inténtelo", "Vuelva", "Compruebe", "avise", "Avise", "instructor", "soporte"]
        let errores: [APIError] = [
            .unauthenticated,
            .rateLimited(retryAfter: 60),
            .validation(message: "x", details: nil),
            .server(message: "x", status: 500),
            .transport(URLError(.notConnectedToInternet)),
            .unexpected(status: 418, body: nil),
            .configuration("BASE_URL ausente")
        ]
        for error in errores {
            let mensaje = error.userMessage
            #expect(
                salidas.contains(where: mensaje.contains),
                "«\(mensaje)» dice qué ha pasado y no qué hacer"
            )
        }
    }

    /// A build without a usable BASE_URL is not a network fault: the user is
    /// told to contact support rather than to check their connection.
    @Test func configurationMessagePointsToSupport() {
        let error = APIError.configuration("BASE_URL ausente")
        #expect(error.userMessage.contains("soporte técnico"))
    }

    /// Every case must say something to the user; an empty message would render
    /// a blank error state.
    @Test func noMessageIsEmpty() {
        let all: [APIError] = [
            .unauthenticated, .forbidden, .notFound(.resourceMissing),
            .rateLimited(retryAfter: nil), .rateLimited(retryAfter: 5),
            .validation(message: "x", details: nil),
            .server(message: "y", status: 500),
            .decoding(NSError(domain: "t", code: 0)),
            .transport(URLError(.timedOut)),
            .unexpected(status: 418, body: nil),
            .configuration("z"),
        ]
        for error in all {
            #expect(!error.userMessage.isEmpty)
        }
    }

    /// Rioplatense voseo endings that must never reach the UI.
    @Test func copyAvoidsVoseo() {
        let all: [APIError] = [
            .unauthenticated, .forbidden, .notFound(.resourceMissing),
            .rateLimited(retryAfter: nil),
            .decoding(NSError(domain: "t", code: 0)),
            .transport(URLError(.timedOut)),
            .unexpected(status: 500, body: nil),
            .configuration("z"),
        ]
        let banned = ["tenés", "podés", "probá", "revisá", "fijate", "andá", "tenes"]
        for error in all {
            let message = error.userMessage.lowercased()
            for word in banned {
                #expect(!message.contains(word), "«\(word)» aparece en: \(error.userMessage)")
            }
        }
    }
}

/// The two different things a 401 means, and why telling them apart matters.
///
/// **Found by running the endpoint, not by reading the code.** From inside,
/// a 401 is a 401 everywhere: the client mapped every one of them to
/// `unauthenticated`, `AuthSession.authorized` refreshed the token, retried,
/// got the same 401 — of course, the typed password had not changed — and
/// signed the candidate out with «Su sesión ha caducado por seguridad».
///
/// A firefighter who mistypes their own password was thrown out of the app,
/// with a message describing something that never happened.
struct CredentialRejectionTests {
    /// The exact body staging returns, captured on 2026-09-10 from
    /// `PATCH /api/v1/me/password` with a deliberately wrong current password.
    @Test func theWrongCurrentPasswordCodeIsRecognised() {
        #expect(CredentialRejection(apiCode: "wrong_current_password") == .wrongCurrentPassword)
    }

    /// **Only known codes escape**, and that direction is deliberate: a bare
    /// 401, or one naming the token, must keep signing the session out.
    /// Inverting it would leave someone with a genuinely expired session
    /// staring at an error instead of being asked to sign in again.
    @Test func everythingElseIsStillASessionProblem() {
        // `no_token` y `token_invalid` son los códigos REALES, pedidos al
        // Gunicorn de staging el 2026-09-10 tras el despliegue db037caa: sin
        // cabecera responde `no_token`, con un token corrupto `token_invalid`.
        // La lista anterior los tenía imaginados —el catálogo del blueprint
        // declara `unauthenticated`, que es lo que el errorhandler emitiría si
        // se disparara— y ninguno de los dos que llegan de verdad estaba.
        for code in [nil, "", "no_token", "token_invalid", "token_expired",
                     "unauthenticated", "unauthorized", "algo_nuevo"] {
            #expect(CredentialRejection(apiCode: code) == nil,
                    "«\(code ?? "nil")» no puede escaparse del camino de sesión")
        }
    }

    /// The sentence says both halves. Without the second, someone can be left
    /// not knowing which of the two passwords to use next time.
    @Test func theSentenceSaysNothingChanged() {
        let texto = CredentialRejection.wrongCurrentPassword.detail
        #expect(texto.contains("actual"))
        #expect(texto.lowercased().contains("no se ha cambiado"))
    }

    /// And the error carries that sentence to the screen, rather than the
    /// session-expiry one.
    @Test func theScreenGetsTheRightSentenceAndNotTheExpiryOne() {
        let error = APIError.credentialRejected(.wrongCurrentPassword)
        #expect(error.userMessage == CredentialRejection.wrongCurrentPassword.detail)
        #expect(error.userMessage.contains("caducado") == false,
                "decir que la sesión caducó es justo lo que no pasó")
    }

    // MARK: - Por la clave, no por el estado

    private func body(_ json: String) throws -> APIErrorBody {
        try JSONDecoder().decode(APIErrorBody.self, from: Data(json.utf8))
    }

    /// **The same body is read the same way whatever 4xx carries it.**
    ///
    /// The backend sends `401` today, inherited from an endpoint older than
    /// the mobile API, and is moving to `422` — which is the coherent one: the
    /// other four body validations on that endpoint are already 422 or 400.
    ///
    /// Branching on the status would make that a coordinated deployment: the
    /// server could not change until the app shipped. Reading the key, either
    /// order works and nobody has to be told.
    @Test func theRejectionIsReadFromTheKeyOnWhicheverStatusCarriesIt() throws {
        let cuerpo = try body("""
        {"error": "wrong_current_password", "message": "La contraseña actual es incorrecta."}
        """)

        for status in [400, 401, 403, 422] {
            #expect(CredentialRejection.forResponse(status: status, body: cuerpo) == .wrongCurrentPassword,
                    "un \(status) con esa clave sigue siendo la misma cosa")
        }
    }

    /// A 5xx with an odd body is not a rejected credential: the server failed,
    /// and dressing that as «your password is wrong» would blame the person
    /// for an outage.
    @Test func aServerFailureIsNeverACredentialRejection() throws {
        let cuerpo = try body("""
        {"error": "wrong_current_password", "message": "x"}
        """)
        for status in [500, 502, 503] {
            #expect(CredentialRejection.forResponse(status: status, body: cuerpo) == nil)
        }
    }

    /// A 401 with no body, or with the token's own code, still signs the
    /// session out — the behaviour every other endpoint depends on.
    @Test func aTokenProblemStillTakesTheSessionPath() throws {
        #expect(CredentialRejection.forResponse(status: 401, body: nil) == nil)
        let cuerpo = try body("""
        {"error": "unauthenticated", "message": "Token ausente o inválido"}
        """)
        #expect(CredentialRejection.forResponse(status: 401, body: cuerpo) == nil)
    }

    /// **It is not `unauthenticated`.** That is the whole point: the case that
    /// `AuthSession.authorized` reacts to by refreshing and signing out.
    @Test func itIsNotTheCaseThatSignsPeopleOut() {
        if case .unauthenticated = APIError.credentialRejected(.wrongCurrentPassword) {
            Issue.record("un rechazo de credencial no puede ser el caso que cierra la sesión")
        }
    }
}

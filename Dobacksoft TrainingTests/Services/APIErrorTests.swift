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

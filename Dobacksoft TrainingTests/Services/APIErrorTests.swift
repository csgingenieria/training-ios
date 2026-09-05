import Testing
import Foundation

@testable import Dobacksoft_Training

struct APIErrorTests {
    @Test func unauthenticatedMessage() {
        let error = APIError.unauthenticated
        #expect(error.userMessage == "Sesión expirada o credenciales inválidas.")
    }

    @Test func forbiddenMessage() {
        let error = APIError.forbidden
        #expect(error.userMessage == "No tenés permisos para esta sección.")
    }

    @Test func notFoundMessage() {
        let error = APIError.notFound
        #expect(error.userMessage == "Recurso no encontrado.")
    }

    @Test func rateLimitedWithRetryAfter() {
        let error = APIError.rateLimited(retryAfter: 30)
        #expect(error.userMessage == "Demasiadas peticiones. Probá en 30s.")
    }

    @Test func rateLimitedWithoutRetryAfter() {
        let error = APIError.rateLimited(retryAfter: nil)
        #expect(error.userMessage == "Demasiadas peticiones. Probá más tarde.")
    }

    @Test func validationMessage() {
        let error = APIError.validation(message: "Email inválido", details: nil)
        #expect(error.userMessage == "Email inválido")
    }

    @Test func serverErrorMessage() {
        let error = APIError.server(message: "Error interno", status: 500)
        #expect(error.userMessage == "Error interno")
    }

    @Test func decodingMessage() {
        let error = APIError.decoding(NSError(domain: "test", code: 0))
        #expect(error.userMessage == "Respuesta inesperada del servidor.")
    }

    @Test func transportMessage() {
        let error = APIError.transport(URLError(.notConnectedToInternet))
        #expect(error.userMessage == "Error de conexión. Revisá tu red.")
    }

    @Test func unexpectedMessage() {
        let error = APIError.unexpected(status: 418, body: "teapot")
        #expect(error.userMessage == "Error inesperado (418).")
    }
}

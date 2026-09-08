import Testing
import Foundation

@testable import Dobacksoft_Training

struct AppEnvironmentTests {
    /// A misconfigured build used to call `fatalError`, crashing on launch in
    /// the hands of a firefighter. Resolution now reports the problem instead.
    @Test func missingKeyIsReportedNotFatal() {
        #expect(throws: AppEnvironment.ConfigurationError.self) {
            try AppEnvironment.resolveBaseURL(from: [:])
        }
    }

    @Test func blankValueIsRejected() {
        #expect(throws: AppEnvironment.ConfigurationError.self) {
            try AppEnvironment.resolveBaseURL(from: ["BASE_URL": "   "])
        }
    }

    /// A relative string parses fine as a URL but cannot serve as a base, so
    /// requests would silently target nowhere.
    @Test func urlWithoutSchemeOrHostIsRejected() {
        #expect(throws: AppEnvironment.ConfigurationError.self) {
            try AppEnvironment.resolveBaseURL(from: ["BASE_URL": "dobacksoft-training.duckdns.org"])
        }
    }

    @Test func validHTTPSURLResolves() throws {
        let url = try AppEnvironment.resolveBaseURL(
            from: ["BASE_URL": "https://dobacksoft-training.duckdns.org"]
        )
        #expect(url.scheme == "https")
        #expect(url.host() == "dobacksoft-training.duckdns.org")
    }

    @Test func surroundingWhitespaceIsTrimmed() throws {
        let url = try AppEnvironment.resolveBaseURL(from: ["BASE_URL": "  https://example.org  "])
        #expect(url.absoluteString == "https://example.org")
    }

    @Test func userAgentIdentifiesTheClient() {
        #expect(AppEnvironment.userAgent.hasPrefix("DobacksoftTraining/"))
    }
}

/// `?conv_id=` must never travel empty.
///
/// The backend answers 400 on purpose: its own service gates the filter with a
/// real `if`, so an empty string would fall through to the fallback and answer
/// about ANOTHER convocatoria wearing the shape of a correct response. A
/// candidate reading someone else's grade is worse than an error.
@Suite struct ProgressQueryTests {
    @Test func aConvocatoriaTravelsAsAQueryParameter() {
        #expect(ProgressQuery.path(convocatoriaId: "c-1") == "/api/v1/me/progress?conv_id=c-1")
    }

    @Test func noConvocatoriaOmitsTheParameterInsteadOfSendingItEmpty() {
        #expect(ProgressQuery.path(convocatoriaId: nil) == "/api/v1/me/progress")
        #expect(ProgressQuery.path(convocatoriaId: "") == "/api/v1/me/progress")
        #expect(ProgressQuery.path(convocatoriaId: "   ") == "/api/v1/me/progress")
    }

    @Test func theEmptyParameterNeverAppears() {
        for id in [nil, "", "  "] as [String?] {
            #expect(ProgressQuery.path(convocatoriaId: id).contains("conv_id=") == false)
        }
    }
}

/// `?conv_id=` on the route detail, with the same discipline as the progress
/// screen: empty is a 400, and worse, the backend's own fallback would answer
/// about another convocatoria wearing the shape of a correct response.
@Suite struct RouteQueryTests {
    @Test func aConvocatoriaTravelsAsAQueryParameter() {
        #expect(RouteQuery.path(code: "2A1", convocatoriaId: "c-1")
                == "/api/v1/me/routes/2A1?conv_id=c-1")
    }

    @Test func noConvocatoriaOmitsTheParameterInsteadOfSendingItEmpty() {
        for vacio in [nil, "", "   "] as [String?] {
            #expect(RouteQuery.path(code: "2A1", convocatoriaId: vacio) == "/api/v1/me/routes/2A1")
        }
    }

    /// Route codes come from the catalogue and nothing in the contract promises
    /// they are URL-safe. A space in a code would break the path silently.
    @Test func theCodeIsEncodedForTheUrl() {
        let path = RouteQuery.path(code: "2A 1/B", convocatoriaId: nil)

        #expect(path.contains(" ") == false)
        #expect(path.hasPrefix("/api/v1/me/routes/"))
    }
}

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

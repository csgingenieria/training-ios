import Testing
import Foundation

@testable import Dobacksoft_Training

/// Three different 404s used to look identical to the app.
///
/// Two of them are not errors at all: not being enrolled is a fact, and having
/// no position yet is the normal state of everyone at the start of a
/// convocatoria. Showing an error screen for those tells a firefighter
/// something went wrong when nothing did.
struct NotFoundReasonTests {
    @Test func recognisesTheThreeCodes() {
        #expect(NotFoundReason(apiCode: "not_enrolled") == .notEnrolled)
        #expect(NotFoundReason(apiCode: "no_standing_yet") == .noStandingYet)
        #expect(NotFoundReason(apiCode: "not_found") == .resourceMissing)
    }

    /// Six other endpoints reuse the generic `not_found`, and other clients may
    /// send codes this build does not know. Neither may be read as a guess.
    @Test func unknownCodesFallBackToGeneric() {
        #expect(NotFoundReason(apiCode: nil) == .resourceMissing)
        #expect(NotFoundReason(apiCode: "") == .resourceMissing)
        #expect(NotFoundReason(apiCode: "algo_nuevo") == .resourceMissing)
    }

    /// The distinction that matters: only one of the three is a failure.
    @Test func onlyTheGenericOneIsAnError() {
        #expect(!NotFoundReason.notEnrolled.isFailure)
        #expect(!NotFoundReason.noStandingYet.isFailure)
        #expect(NotFoundReason.resourceMissing.isFailure)
    }

    @Test func eachOneSaysSomethingDifferent() {
        let messages = Set([
            NotFoundReason.notEnrolled.title,
            NotFoundReason.noStandingYet.title,
            NotFoundReason.resourceMissing.title,
        ])
        #expect(messages.count == 3)
    }

    /// Copy must not imply a verdict or a duty.
    @Test func copyStaysWithinArticle22() {
        for reason in [NotFoundReason.notEnrolled, .noStandingYet, .resourceMissing] {
            let text = (reason.title + " " + reason.detail).lowercased()
            for banned in ["apto", "suspens", "aprob", "corte", "cupo", "debe", "falta"] {
                #expect(!text.contains(banned), "«\(banned)» en: \(text)")
            }
        }
    }

    /// The API sends the code under `error`, not `code`. Reading the wrong key
    /// would silently degrade every 404 to the generic one.
    @Test func decodesFromTheRealErrorBody() throws {
        let json = Data(#"{"error": "no_standing_yet", "message": "Sin posición en el ranking"}"#.utf8)

        let body = try JSONDecoder().decode(APIErrorBody.self, from: json)

        #expect(NotFoundReason(apiCode: body.error) == .noStandingYet)
    }

    @Test func apiErrorCarriesTheReason() {
        let error = APIError.notFound(.noStandingYet)
        #expect(error.notFoundReason == .noStandingYet)
        #expect(APIError.forbidden.notFoundReason == nil)
    }
}

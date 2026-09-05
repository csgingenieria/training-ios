import Testing
import Foundation

@testable import Dobacksoft_Training

struct DataQualityTests {
    @Test func parsesTheThreeBackendValues() {
        #expect(DataQuality(apiValue: "HIGH") == .high)
        #expect(DataQuality(apiValue: "MEDIUM") == .medium)
        #expect(DataQuality(apiValue: "LOW") == .low)
    }

    @Test func parsingIsCaseInsensitiveAndTrimsWhitespace() {
        #expect(DataQuality(apiValue: "high") == .high)
        #expect(DataQuality(apiValue: "  Medium  ") == .medium)
    }

    @Test func unknownOrMissingValuesYieldNil() {
        #expect(DataQuality(apiValue: nil) == nil)
        #expect(DataQuality(apiValue: "") == nil)
        #expect(DataQuality(apiValue: "UNRATED") == nil)
    }

    /// The badge used to render the raw backend token, so a firefighter read
    /// "HIGH" in English. UI copy is Spanish.
    @Test func labelsAreSpanish() {
        #expect(DataQuality.high.label == "Calidad alta")
        #expect(DataQuality.medium.label == "Calidad media")
        #expect(DataQuality.low.label == "Calidad baja")
    }

    @Test func attemptSummaryExposesParsedQuality() throws {
        let dto: MyAttemptsListDTO = try JSONFixture.decode("my-attempts")
        #expect(dto.items[0].quality == .high)
        #expect(dto.items[1].quality == .medium)
        #expect(dto.items[2].quality == .low)
    }
}

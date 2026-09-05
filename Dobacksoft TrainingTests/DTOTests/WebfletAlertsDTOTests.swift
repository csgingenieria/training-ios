import Testing
import Foundation

@testable import Dobacksoft_Training

struct WebfletAlertsDTOTests {
    @Test func decodeMixedAlerts() throws {
        let dto: WebfletAlertsResponseDTO = try JSONFixture.decode("webflet-alerts")
        #expect(dto.count == 3)
        #expect(dto.items.count == 3)

        let error = dto.items[0]
        #expect(error.attemptId == "atm-501")
        #expect(error.severity == .error)
        #expect(error.type == "WEBFLEET_ENRICHMENT_FAILED")
        #expect(error.studentName == "María García")

        let warning = dto.items[1]
        #expect(warning.severity == .warning)
        #expect(warning.message?.contains("rotativos") == true)
    }

    /// Defense en `WebfletAlertSeverity.init`: si llegan severities desconocidas
    /// no rompe el decode (forward-compat) — cae a `.unknown`.
    @Test func unknownSeverityFallsBack() throws {
        let json = """
        {
          "items": [{
            "attemptId": "atm-x",
            "severity": "info",
            "type": "FUTURE_TYPE",
            "message": null,
            "studentName": null,
            "timestamp": null
          }],
          "count": 1
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(WebfletAlertsResponseDTO.self, from: json)
        #expect(dto.items[0].severity == .unknown)
    }

    @Test func optionalFieldsAreNullable() throws {
        let dto: WebfletAlertsResponseDTO = try JSONFixture.decode("webflet-alerts")
        let third = dto.items[2]
        #expect(third.message == nil)
        #expect(third.studentName == nil)
        #expect(third.timestamp == nil)
        // attemptId, severity, type NO son nullable según el schema backend
        #expect(!third.attemptId.isEmpty)
        #expect(!third.type.isEmpty)
    }

    @Test func decodeEmptyFeed() throws {
        let json = #"{ "items": [], "count": 0 }"#.data(using: .utf8)!
        let dto = try JSONDecoder().decode(WebfletAlertsResponseDTO.self, from: json)
        #expect(dto.items.isEmpty)
        #expect(dto.count == 0)
    }
}

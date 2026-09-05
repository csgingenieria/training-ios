import Testing
import Foundation

@testable import Dobacksoft_Training

struct ManagerDashboardDTOTests {
    @Test func decodeFullDashboard() throws {
        let dto: ManagerDashboardDTO = try JSONFixture.decode("manager-dashboard")
        #expect(dto.activeConvocatorias == 3)
        #expect(dto.totalCandidates == 120)
        #expect(dto.totalParticipants == 60)
        #expect(dto.attemptsToday == 42)
        #expect(dto.attemptsThisWeek == 187)
        #expect(dto.lastWebfleetSyncAt == "2026-06-09T08:00:00+00:00")
        #expect(dto.convocatoriasWithLowQuality == 1)
    }

    /// El backend documenta `lastWebfleetSyncAt: null` cuando ningún intento se
    /// sincronizó todavía. La app lo trata como "Sin datos sincronizados todavía".
    @Test func decodeWithoutWebfletSync() throws {
        let json = """
        {
            "activeConvocatorias": 0,
            "totalCandidates": 0,
            "totalParticipants": 0,
            "attemptsToday": 0,
            "attemptsThisWeek": 0,
            "lastWebfleetSyncAt": null,
            "convocatoriasWithLowQuality": 0
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(ManagerDashboardDTO.self, from: json)
        #expect(dto.lastWebfleetSyncAt == nil)
        #expect(dto.activeConvocatorias == 0)
    }
}

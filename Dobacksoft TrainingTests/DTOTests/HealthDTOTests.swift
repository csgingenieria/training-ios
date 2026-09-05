import Testing
import Foundation

@testable import Dobacksoft_Training

struct HealthDTOTests {
    @Test func decodeHealthResponse() throws {
        let dto: HealthDTO = try JSONFixture.decode("health")
        #expect(dto.status == "ok")
        #expect(dto.version == "v1")
        #expect(dto.time == "2026-05-24T12:00:00+00:00")
    }
}

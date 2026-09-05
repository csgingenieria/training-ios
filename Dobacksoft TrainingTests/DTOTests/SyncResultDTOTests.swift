import Testing
import Foundation

@testable import Dobacksoft_Training

struct SyncResultDTOTests {
    @Test func decodeMixedCounters() throws {
        let dto: SyncResultDTO = try JSONFixture.decode("sync-result")
        #expect(dto.ok == true)

        // ftp solo tiene ints
        let ftpFiles = dto.ftp["filesProcessed"]
        #expect(ftpFiles?.display == "12")

        // webfleet mezcla ints y strings — el decoder defensivo soporta ambos.
        let lastError = dto.webfleet["lastError"]
        if case .string(let s) = lastError {
            #expect(s.contains("503"))
        } else {
            Issue.record("lastError debería decodificar como string")
        }

        let enriched = dto.webfleet["attemptsEnriched"]
        if case .int(let n) = enriched {
            #expect(n == 18)
        } else {
            Issue.record("attemptsEnriched debería decodificar como int")
        }
    }

    @Test func decodeMinimalSuccess() throws {
        let json = #"{ "ok": true, "ftp": {}, "webfleet": {} }"#.data(using: .utf8)!
        let dto = try JSONDecoder().decode(SyncResultDTO.self, from: json)
        #expect(dto.ok)
        #expect(dto.ftp.isEmpty)
        #expect(dto.webfleet.isEmpty)
    }

    @Test func counterDisplayHandlesAllCases() throws {
        #expect(SyncCounter.int(42).display == "42")
        #expect(SyncCounter.string("err").display == "err")
        #expect(SyncCounter.unknown.display == "—")
    }
}

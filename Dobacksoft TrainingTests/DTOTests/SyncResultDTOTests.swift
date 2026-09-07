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

/// The exact body `POST /api/v1/me/webfleet/sync` returned from staging on
/// 2026-09-07 — the one endpoint that had never been called, because it
/// actually triggers a fleet sync and needed the owner's word first.
///
/// It settles the reason `SyncCounter` decodes defensively: `ftp` mixes an
/// integer count with a **string** status in the same dictionary. A
/// `[String: Int]` would have thrown away the whole response, and the manager
/// would have seen a decoding error after a sync that ran fine.
struct SyncResultRealPayloadTests {
    private func real() throws -> SyncResultDTO {
        let json = Data("""
        {
          "ok": true,
          "ftp": {"failed": 0, "processed": 0, "skipped": 66, "status": "done"},
          "webfleet": {
            "attempts": 0, "autoclosed": 0, "errors": 0,
            "skippedNoWebfleet": 0, "syncedGps": 0, "syncedRot": 0
          }
        }
        """.utf8)
        return try JSONDecoder().decode(SyncResultDTO.self, from: json)
    }

    @Test func theRealBodyDecodes() throws {
        let dto = try real()
        #expect(dto.ok)
        #expect(dto.ftp.count == 4)
        #expect(dto.webfleet.count == 6)
    }

    /// The mixed dictionary, which is the whole point.
    @Test func integersAndStringsShareOneDictionary() throws {
        let ftp = try real().ftp

        #expect(ftp["skipped"] == .int(66))
        #expect(ftp["status"] == .string("done"))
        #expect(ftp["skipped"]?.display == "66")
        #expect(ftp["status"]?.display == "done")
    }

    /// Keys are not pinned in the backend schema and may evolve, so the UI
    /// iterates them generically. What must not happen is a new key or type
    /// bringing the response down.
    @Test func anUnexpectedKeyOrTypeDoesNotSinkTheResponse() throws {
        let json = Data("""
        {
          "ok": true,
          "ftp": {"processed": 3, "status": "done", "ratio": 0.75, "detail": null},
          "webfleet": {"clave_de_manana": 1}
        }
        """.utf8)

        let dto = try JSONDecoder().decode(SyncResultDTO.self, from: json)

        #expect(dto.ok)
        #expect(dto.ftp["ratio"] == .int(0))          // 0.75 -> Int(0), no revienta
        #expect(dto.ftp["detail"] == .unknown)
        #expect(dto.ftp["detail"]?.display == "—")
        #expect(dto.webfleet["clave_de_manana"] == .int(1))
    }

    /// GDPR art. 22: a fleet sync reports counters, never an outcome.
    @Test func noCounterStatesAnOutcome() throws {
        let dto = try real()

        // En una sola expresión el type-checker de Swift se rinde: hay que
        // partirla, no adornarla.
        var pieces: [String] = []
        pieces.append(contentsOf: dto.ftp.keys)
        pieces.append(contentsOf: dto.webfleet.keys)
        pieces.append(contentsOf: dto.ftp.values.map(\.display))
        pieces.append(contentsOf: dto.webfleet.values.map(\.display))
        let text = pieces.joined(separator: " ").lowercased()

        for banned in ["apto", "suspens", "aprob", "corte", "plaza", "cupo"] {
            #expect(!text.contains(banned), "«\(banned)» en el resultado del sync")
        }
    }
}

import Testing
import Foundation

@testable import Dobacksoft_Training

/// Notes are written the way the web portal writes them.
///
/// The app printed «8.50» in eleven places — a dot, and two decimals — while
/// the portal the client already accepted prints «8,5». Spanish uses a comma,
/// and a candidate reading one figure on the phone and another on the portal is
/// not looking at the same system.
struct ScoreFormatTests {
    /// One attempt's own note: one decimal, matching `%.1f` in the portal's
    /// `resultados.html` and `alumno.html`.
    @Test func anAttemptNoteTakesOneDecimal() {
        #expect(ScoreFormat.attempt(8.5) == "8,5")
        #expect(ScoreFormat.attempt(10.0) == "10,0")
        #expect(ScoreFormat.attempt(0.0) == "0,0")
    }

    /// Aggregates keep two, because a mean over ten routes lands on quarters
    /// and 4,75 rounded to 4,8 is a different number from the one on the record.
    @Test func aggregatesKeepTwoDecimals() {
        #expect(ScoreFormat.aggregate(4.75) == "4,75")
        #expect(ScoreFormat.aggregate(0.85) == "0,85")
        #expect(ScoreFormat.aggregate(9.5) == "9,50")
    }

    @Test func breakdownComponentsKeepTwoDecimals() {
        #expect(ScoreFormat.component(3.75) == "3,75")
        #expect(ScoreFormat.component(2.21) == "2,21")
        #expect(ScoreFormat.component(0.0) == "0,00")
    }

    /// The separator is fixed, not taken from the device.
    ///
    /// Every label around the number is hardcoded Spanish, so a phone set to
    /// English must not start printing «8.5» in the middle of it.
    @Test func neverADot() {
        let all = [
            ScoreFormat.attempt(8.5), ScoreFormat.attempt(0.0),
            ScoreFormat.aggregate(4.75), ScoreFormat.aggregate(10.0),
            ScoreFormat.component(1.875),
        ]
        for text in all {
            #expect(!text.contains("."), "«\(text)» lleva punto decimal")
            #expect(text.contains(","))
        }
    }

    /// The rounding a real payload produces, so the numbers on screen are the
    /// ones staging actually returned for a live attempt.
    @Test func realPayloadRoundsAsThePortalDoes() {
        // attempt 94815dce… : score 8.5, allison and webfleet weights 1.875.
        #expect(ScoreFormat.attempt(8.5) == "8,5")
        #expect(ScoreFormat.component(1.875) == "1,88")
        // ranking leader: 9.5 average over 10 required routes -> 4.75 official.
        #expect(ScoreFormat.aggregate(9.5) == "9,50")
        #expect(ScoreFormat.aggregate(4.75) == "4,75")
    }
}

/// `score` and `scoreRaw` are two different numbers, not one rounded twice.
///
/// Confirmed by the Training team and verified against staging for attempt
/// 94815dce…: the exact grade is 8,464375 and is not published; `score` is 8,5
/// with one significant decimal; `scoreRaw` is 8,46; and the breakdown rows add
/// up to 8,45. The rows will never reproduce `score` — it already lost a
/// decimal — but they land within ±0,01 per row of `scoreRaw`.
struct PublishedGradeTests {
    private func attempt() throws -> AttemptDetailDTO {
        let json = Data("""
        {
          "id": "at-1", "convocatoriaId": "conv-1", "dataQuality": "HIGH",
          "scoreModel": "D10-W", "score": 8.5, "scoreRaw": 8.46,
          "candidate": {"id": "c1", "name": "Nombre Aspirante"},
          "route": {"id": "2A2", "label": "2A2", "name": "2A2 Un recorrido", "categoria": "EXAMEN"},
          "events": [],
          "scoreBreakdown": [
            {"key": "estabilidad", "family": "Estabilidad (deducciones)", "max": 3.75, "obtained": 2.21, "state": null, "reason": null},
            {"key": "velocidad", "family": "Velocidad (excesos por vía)", "max": 0.0, "obtained": null, "state": "no_medido", "reason": "webfleet_poco_muestreo"},
            {"key": "freno_motor", "family": "Uso del freno motor", "max": 2.5, "obtained": 2.5, "state": null, "reason": null},
            {"key": "allison", "family": "Uso de la caja Allison", "max": 1.87, "obtained": 1.87, "state": null, "reason": null},
            {"key": "webfleet", "family": "Conducción (eventos de Webfleet)", "max": 1.87, "obtained": 1.87, "state": null, "reason": null}
          ]
        }
        """.utf8)
        return try JSONDecoder().decode(AttemptDetailDTO.self, from: json)
    }

    @Test func thePublishedGradeTakesOneDecimal() throws {
        let dto = try attempt()
        #expect(ScoreFormat.attempt(try #require(dto.score)) == "8,5")
    }

    @Test func scoreRawTravelsAndKeepsTwo() throws {
        let dto = try attempt()
        #expect(ScoreFormat.aggregate(try #require(dto.scoreRaw)) == "8,46")
    }

    /// The rows do not add up to the published grade, and the app must not
    /// pretend otherwise. This pins the gap so nobody later "fixes" it by
    /// deriving the grade from the rows.
    @Test func theRowsDoNotAddUpToTheGrade() throws {
        let dto = try attempt()
        let sum = dto.scoreBreakdown.compactMap(\.obtained).reduce(0, +)

        #expect(abs(sum - 8.45) < 0.001)
        #expect(sum != dto.score)
        // Lo que importa no es un épsilon inventado, sino de qué número se
        // acercan: de `scoreRaw`, nunca de `score`, que ya perdió un decimal.
        let toRaw = abs(sum - (dto.scoreRaw ?? 0))
        let toPublished = abs(sum - (dto.score ?? 0))
        #expect(toRaw < toPublished)
    }

    /// The weights do not add up to 10,00 and it is documented that they never
    /// will: squaring the total broke `obtained <= max` on a perfect row.
    @Test func theWeightsDoNotAddUpToTen() throws {
        let dto = try attempt()
        let weights = dto.scoreBreakdown.compactMap(\.max).reduce(0, +)

        #expect(abs(weights - 9.99) < 0.001)
        #expect(weights != 10.0)
    }

    /// The invariants the backend does guarantee, per row.
    @Test func obtainedNeverExceedsItsWeight() throws {
        for row in try attempt().scoreBreakdown {
            #expect((row.obtained ?? 0) <= (row.max ?? 0), "\(row.key ?? "?") rompe obtained <= max")
        }
        let perfect = try #require(try attempt().scoreBreakdown.first { $0.key == "freno_motor" })
        #expect(perfect.obtained == perfect.max)
    }
}

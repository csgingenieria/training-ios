import Testing
import Foundation

@testable import Dobacksoft_Training

/// `GET /api/v1/me/routes/<code>` — the per-route detail, block D. The last one.
///
/// Two things here decide whether the screen tells the truth:
///
/// - `required` says whether the route counts towards the official grade. With
///   declared required routes only those count; with none declared, ALL of them
///   do, so it arrives `true`. A screen that got this backwards would tell a
///   candidate their 10 does not count when it does, or the opposite.
/// - `scoredAttempts` counts attempts WITH A GRADE, not «closed». The backend
///   renamed it for that reason: the derived state cannot tell a closed attempt
///   with no grade from one waiting for the truck's data, so «closed» would
///   have been a number that does not count closed things.
struct RouteDetailDTOTests {
    private func decode(_ json: String) throws -> RouteDetailDTO {
        try JSONDecoder().decode(RouteDetailDTO.self, from: Data(json.utf8))
    }

    private let completo = #"""
    {
      "route": {"code": "2A1", "name": "Parque → Hoyo", "description": "Subida por la M-618",
                "distanceKm": 12.4, "durationMin": 45, "active": true, "required": true},
      "waypoints": [{"order": 1, "lat": 40.1, "lng": -3.7, "name": "Salida"},
                    {"order": 2, "lat": 40.2, "lng": -3.8, "name": "Meta"}],
      "attempts": [{"id": "a-1", "score": 8.5, "state": "CON_NOTA",
                    "route": {"id": "2A1", "label": "2A1"}}],
      "stats": {"scoredAttempts": 1, "listedAttempts": 3, "bestScore": 8.5,
                "bestAttemptId": "a-1", "lastScore": 6.0, "lastAttemptId": "a-3",
                "lastAt": "2026-09-07T10:00:00Z"},
      "candidate": {"id": "s-1", "name": "Aspirante"},
      "convocatoria": {"id": "c-1", "name": "Oposición 2026", "closedAt": null}
    }
    """#

    @Test func theWholeDetailDecodes() throws {
        let d = try decode(completo)

        #expect(d.route?.code == "2A1")
        #expect(d.route?.name == "Parque → Hoyo")
        #expect(d.waypoints.count == 2)
        #expect(d.attempts.count == 1)
        #expect(d.stats?.scoredAttempts == 1)
        #expect(d.convocatoria?.name == "Oposición 2026")
    }

    // MARK: - required, que decide una frase

    @Test func aRequiredRouteCountsTowardsTheGrade() throws {
        let d = try decode(completo)

        #expect(d.route?.required == true)
        #expect(d.route?.countsTowardsTheGrade == true)
    }

    /// A route that is not required does not move the official grade, and the
    /// screen has to say it: without that sentence a candidate does not
    /// understand why their 10 changed nothing.
    @Test func aRouteThatIsNotRequiredSaysSo() throws {
        let d = try decode(#"{"route": {"code": "2A1", "required": false}}"#)

        #expect(d.route?.countsTowardsTheGrade == false)
    }

    /// Absent is not `false`. Without the field nothing is claimed, because
    /// claiming a route does not count is as wrong as claiming it does.
    @Test func anAbsentRequiredFlagClaimsNothing() throws {
        let d = try decode(#"{"route": {"code": "2A1"}}"#)

        #expect(d.route?.required == nil)
        #expect(d.route?.countsTowardsTheGrade == nil)
    }

    // MARK: - stats, y el nombre que el backend corrigió

    /// The two numbers count different things and the screen must not present
    /// one as the other: three laps driven, one graded.
    @Test func gradedAndDrivenAreDifferentNumbers() throws {
        let stats = try #require(try decode(completo).stats)

        #expect(stats.scoredAttempts == 1)
        #expect(stats.listedAttempts == 3)
        #expect(stats.hasUngradedAttempts, "dos vueltas conducidas todavía sin nota")
    }

    @Test func withEverythingGradedThereIsNothingPending() throws {
        let d = try decode(#"{"stats": {"scoredAttempts": 3, "listedAttempts": 3}}"#)

        #expect(try #require(d.stats).hasUngradedAttempts == false)
    }

    /// `bestScore` and `lastScore` answer different questions, and on this
    /// screen they can disagree: the best lap is not the last one.
    @Test func theBestLapIsNotNecessarilyTheLast() throws {
        let stats = try #require(try decode(completo).stats)

        #expect(stats.bestScore == 8.5)
        #expect(stats.lastScore == 6.0)
        #expect(stats.bestAttemptId != stats.lastAttemptId)
    }

    /// `lastAt` is one instant, and it is never missing when there is a
    /// `lastScore`: they come from the same lap. A grade with no date would
    /// leave the candidate unable to place it.
    @Test func aLastGradeAlwaysCarriesItsInstant() throws {
        let stats = try #require(try decode(completo).stats)

        #expect(stats.lastScore != nil)
        #expect(stats.lastAt != nil)
    }

    @Test func noAttemptsMeansNoNumbersInvented() throws {
        let d = try decode(#"{"stats": {"scoredAttempts": 0, "listedAttempts": 0}}"#)
        let stats = try #require(d.stats)

        #expect(stats.bestScore == nil)
        #expect(stats.lastAt == nil)
        #expect(stats.hasUngradedAttempts == false)
    }

    // MARK: - waypoints

    @Test func waypointsKeepTheirOrderAndTheirPlace() throws {
        let d = try decode(completo)

        #expect(d.waypoints.first?.order == 1)
        #expect(d.waypoints.first?.coordinate != nil)
        #expect(d.drawableRoute.count == 2, "dos puntos ya son una línea")
    }

    /// A waypoint with no coordinates is not drawn: an invented point would
    /// change the shape of the route on the map.
    @Test func aWaypointWithoutCoordinatesIsNotDrawn() throws {
        let d = try decode(#"""
        {"waypoints": [{"order": 1, "lat": 40.1, "lng": -3.7},
                       {"order": 2, "lat": null, "lng": null}]}
        """#)

        #expect(d.waypoints.count == 2)
        #expect(d.drawableRoute.count == 1, "el punto sin sitio no deforma el trazado")
    }

    @Test func anOlderServerWithoutTheFieldsStillDecodes() throws {
        let d = try decode("{}")

        #expect(d.route == nil)
        #expect(d.waypoints.isEmpty)
        #expect(d.attempts.isEmpty)
        #expect(d.stats == nil)
    }
}

import Testing
import Foundation
import SwiftUI

@testable import Dobacksoft_Training

/// When returning to the app reloads its data.
///
/// Nothing observed `scenePhase` anywhere in the app: data loaded once, and a
/// candidate who opened the app the next morning read yesterday's position
/// with nothing saying so. The widget already refused to show a six-hour-old
/// figure unlabelled; the app itself did not.
///
/// The rule lives in a type with an injectable clock so it can be tested with
/// fixed dates. «How long away counts as away» is exactly the sort of
/// threshold that gets nudged by hand and silently turns into «reload on every
/// notification banner».
@MainActor
struct RefreshTickerTests {
    private let t0 = Date(timeIntervalSince1970: 1_757_000_000)

    // MARK: - Cuánto tiempo fuera cuenta como fuera

    /// A glance away — pulling down notification centre, answering a message —
    /// is not an absence. Reloading here would throw away a screen the person
    /// is still reading.
    @Test func aShortAbsenceDoesNotReload() {
        let ticker = RefreshTicker()
        ticker.scenePhaseChanged(to: .background, at: t0)
        ticker.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(60))
        #expect(ticker.generation == 0)
    }

    @Test func aLongAbsenceReloads() {
        let ticker = RefreshTicker()
        ticker.scenePhaseChanged(to: .background, at: t0)
        ticker.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(600))
        #expect(ticker.generation == 1)
    }

    /// The boundary is inclusive, and it is pinned so that nudging the constant
    /// is a deliberate act with a failing test attached.
    @Test func theThresholdIsFiveMinutesExactly() {
        #expect(RefreshTicker.staleAfter == 300)

        let justUnder = RefreshTicker()
        justUnder.scenePhaseChanged(to: .background, at: t0)
        justUnder.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(299))
        #expect(justUnder.generation == 0)

        let exactly = RefreshTicker()
        exactly.scenePhaseChanged(to: .background, at: t0)
        exactly.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(300))
        #expect(exactly.generation == 1)
    }

    // MARK: - Qué NO cuenta como haberse ido

    /// `.inactive` is not an absence: it fires while the app is still on
    /// screen — a banner coming down, the app switcher opening. Counting it
    /// would reload the screen the person never left.
    @Test func inactiveIsNotAnAbsence() {
        let ticker = RefreshTicker()
        ticker.scenePhaseChanged(to: .inactive, at: t0)
        ticker.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(3600))
        #expect(ticker.generation == 0)
    }

    /// Becoming active without ever having left does nothing. This is the
    /// first phase change of every launch, and the screens already load once
    /// on their own: bumping here would load everything twice at startup.
    @Test func becomingActiveWithoutHavingLeftDoesNothing() {
        let ticker = RefreshTicker()
        ticker.scenePhaseChanged(to: .active, at: t0)
        #expect(ticker.generation == 0)
    }

    // MARK: - Cuántas veces

    /// One absence, one reload. The absence is consumed, so a second `.active`
    /// without a new departure does not reload again.
    @Test func oneAbsenceReloadsOnce() {
        let ticker = RefreshTicker()
        ticker.scenePhaseChanged(to: .background, at: t0)
        ticker.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(600))
        ticker.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(700))
        #expect(ticker.generation == 1)
    }

    @Test func twoSeparateAbsencesReloadTwice() {
        let ticker = RefreshTicker()
        ticker.scenePhaseChanged(to: .background, at: t0)
        ticker.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(600))
        ticker.scenePhaseChanged(to: .background, at: t0.addingTimeInterval(700))
        ticker.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(1500))
        #expect(ticker.generation == 2)
    }

    /// A clock that jumps backwards — a manual time change, an NTP
    /// correction — must not reload, and must not leave the ticker stuck
    /// believing it is still away. A negative interval is not five minutes.
    @Test func aClockThatJumpsBackwardsDoesNotReload() {
        let ticker = RefreshTicker()
        ticker.scenePhaseChanged(to: .background, at: t0)
        ticker.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(-3600))
        #expect(ticker.generation == 0)

        // And the absence is cleared, so the next real one still works.
        ticker.scenePhaseChanged(to: .background, at: t0)
        ticker.scenePhaseChanged(to: .active, at: t0.addingTimeInterval(600))
        #expect(ticker.generation == 1)
    }

    // MARK: - La llave que usan las pantallas

    /// Screens that already reload on an id combine it with the generation, so
    /// both reasons to reload survive. Neither alone is enough: keyed on the
    /// id only, coming back never reloads; keyed on the generation only,
    /// changing convocatoria never reloads.
    @Test func theRefreshKeyChangesWithEitherHalf() {
        let a = RefreshKey(id: "c1", generation: 0)
        #expect(a == RefreshKey(id: "c1", generation: 0))
        #expect(a != RefreshKey(id: "c1", generation: 1))
        #expect(a != RefreshKey(id: "c2", generation: 0))
    }

    /// A nil id is a value, not an absence of one: «whatever the backend
    /// considers my active enrolment» is a real selection and must not
    /// collide with a named convocatoria.
    @Test func aNilIdIsItsOwnKey() {
        #expect(RefreshKey(id: String?.none, generation: 0) != RefreshKey(id: "c1", generation: 0))
    }
}

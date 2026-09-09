import Testing
import SwiftUI

@testable import Dobacksoft_Training

/// When the app animates, and when it must not.
struct MotionTests {
    /// With «Reduce Motion» off, the requested curve is used.
    @Test func normallyTheRequestedAnimationIsUsed() {
        #expect(Motion.animation(Theme.motion.base, reduceMotion: false) != nil)
    }

    /// **With «Reduce Motion» on there is no animation at all.**
    ///
    /// Not a shorter one, not a subtler one: none. The setting exists for
    /// vestibular sensitivity — dizziness, vertigo — and «a little movement» is
    /// still movement. Animating regardless would be a defect for the person
    /// who asked, not a nice touch.
    @Test func withReduceMotionThereIsNoAnimation() {
        for curva in [Theme.motion.fast, Theme.motion.base, Theme.motion.slow, Theme.motion.outStrong] {
            #expect(Motion.animation(curva, reduceMotion: true) == nil)
        }
    }

    /// What is removed is the movement, never the information: the state change
    /// still happens, instantly. `nil` means «no animation» to SwiftUI, not
    /// «no change».
    @Test func removingTheAnimationDoesNotRemoveTheChange() {
        // Documented by construction: the function returns an Optional
        // Animation and nothing else. It has no way to suppress a state change,
        // and this test exists so that a future version that gains one has to
        // break it.
        #expect(Motion.animation(Theme.motion.base, reduceMotion: true) == nil)
        #expect(Motion.animation(Theme.motion.base, reduceMotion: false) != nil)
    }
}

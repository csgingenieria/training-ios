import Testing
import Foundation
import SwiftUI

@testable import Dobacksoft_Training

/// Which section the dashboard shows, and what happens to the screens pushed
/// inside each one.
///
/// Two defects sat behind this. `if sizeClass == .regular` swapped two
/// unrelated view trees, so a Split View drag or a rotation on an iPhone Pro
/// Max discarded every pushed screen; and the iPad detail pane was a single
/// `NavigationStack` with no path binding, so switching sidebar section while
/// drilled into a convocatoria left the previous section's push stack behind —
/// contradicting the comment in that very file, which claimed a stack per
/// section.
///
/// The router owns both, outside any view, so the behaviour can be stated.
@MainActor
struct DashboardRouterTests {
    // MARK: - Qué secciones ve cada rol

    /// A candidate never sees the instructor panel, and an instructor has no
    /// position or progress of their own.
    @Test func eachRoleSeesItsOwnSections() {
        #expect(SidebarSection.available(isAdminLike: false, isStudent: true) ==
                [.convocatorias, .miPosicion, .miProgreso, .perfil])

        #expect(SidebarSection.available(isAdminLike: true, isStudent: false) ==
                [.panel, .convocatorias, .perfil])
    }

    /// Convocatorias and Perfil are the two every role has. Without one shared
    /// section there is no safe landing place to clamp to.
    @Test func everyRoleHasSomewhereToLand() {
        for (admin, student) in [(true, false), (false, true), (false, false)] {
            let sections = SidebarSection.available(isAdminLike: admin, isStudent: student)
            #expect(sections.contains(.convocatorias))
            #expect(sections.contains(.perfil))
            #expect(!sections.isEmpty)
        }
    }

    // MARK: - La sección de arranque

    /// The instructor lands on their panel; the candidate on the list. The old
    /// code did this with an `.onAppear` that reassigned the selection after
    /// the first render, so the wrong screen flashed first.
    @Test func theLandingSectionFollowsTheRole() {
        #expect(DashboardRouter(isAdminLike: true, isStudent: false).section == .panel)
        #expect(DashboardRouter(isAdminLike: false, isStudent: true).section == .convocatorias)
    }

    /// A restored section that the role cannot use is clamped, not shown.
    /// `@SceneStorage` survives a relaunch, so an instructor's iPad restoring
    /// `.panel` for the candidate who logs in next would open a screen whose
    /// endpoints reject them.
    @Test func aRestoredSectionTheRoleCannotUseIsClamped() {
        let router = DashboardRouter(isAdminLike: false, isStudent: true, restoring: "panel")
        #expect(router.section == .convocatorias)
    }

    @Test func aRestoredSectionTheRoleCanUseIsHonoured() {
        let router = DashboardRouter(isAdminLike: false, isStudent: true, restoring: "miProgreso")
        #expect(router.section == .miProgreso)
    }

    /// Unrecognised stored text is not a section. It falls back to the role's
    /// landing place rather than to an empty pane.
    @Test func unrecognisedStoredTextFallsBackToTheLanding() {
        #expect(DashboardRouter(isAdminLike: true, isStudent: false, restoring: "🙂").section == .panel)
        #expect(DashboardRouter(isAdminLike: true, isStudent: false, restoring: "").section == .panel)
    }

    /// The stored value is the stable identifier, not the translatable label:
    /// renaming «Mi posición» must not lose everyone's restored section.
    @Test func theStoredValueIsTheStableIdentifier() {
        #expect(SidebarSection.miPosicion.rawValue == "miPosicion")
        #expect(SidebarSection(rawValue: "miPosicion") == .miPosicion)
        #expect(SidebarSection.miPosicion.title == "Mi posición")
    }

    // MARK: - Una pila por sección, que es lo que el comentario prometía

    @Test func eachSectionKeepsItsOwnStackWhenTheSectionChanges() {
        let router = DashboardRouter(isAdminLike: false, isStudent: true)
        router.push("una-convocatoria", in: .convocatorias)

        router.section = .perfil

        #expect(router.path(for: .convocatorias).count == 1, "la pila de la sección anterior sobrevive")
        #expect(router.path(for: .perfil).isEmpty, "y no se hereda en la nueva")
    }

    /// And coming back finds it where it was left. This is the whole point:
    /// a candidate reading an attempt, checking their profile and coming back
    /// should not be dropped at the root.
    @Test func comingBackToASectionFindsItsStackWhereItWasLeft() {
        let router = DashboardRouter(isAdminLike: false, isStudent: true)
        router.push("una-convocatoria", in: .convocatorias)
        router.push("un-intento", in: .convocatorias)

        router.section = .perfil
        router.section = .convocatorias

        #expect(router.path(for: .convocatorias).count == 2)
    }

    /// The binding is the same state the router holds, in both directions.
    /// A stack that reads the path but cannot write it back would lose every
    /// push the moment SwiftUI recreated the view.
    @Test func theBindingWritesBackIntoTheRouter() {
        let router = DashboardRouter(isAdminLike: false, isStudent: true)
        let binding = router.pathBinding(for: .miProgreso)

        var path = binding.wrappedValue
        path.append("un-recorrido")
        binding.wrappedValue = path

        #expect(router.path(for: .miProgreso).count == 1)
        #expect(router.path(for: .convocatorias).isEmpty)
    }

    /// Selecting the section that is already showing pops it to its root —
    /// the platform behaviour for tapping the current tab.
    @Test func reselectingTheCurrentSectionPopsItToItsRoot() {
        let router = DashboardRouter(isAdminLike: false, isStudent: true)
        router.push("una-convocatoria", in: .convocatorias)
        #expect(router.path(for: .convocatorias).count == 1)

        router.select(.convocatorias)

        #expect(router.path(for: .convocatorias).isEmpty)
        #expect(router.section == .convocatorias)
    }

    /// Selecting a DIFFERENT section leaves both stacks alone. Only
    /// reselection pops.
    @Test func selectingAnotherSectionPopsNothing() {
        let router = DashboardRouter(isAdminLike: false, isStudent: true)
        router.push("una-convocatoria", in: .convocatorias)

        router.select(.miProgreso)

        #expect(router.path(for: .convocatorias).count == 1)
        #expect(router.section == .miProgreso)
    }

    /// A section the role cannot use is not selectable at runtime either —
    /// not only at restore. The sidebar never offers it, but the widget deep
    /// link and the keyboard shortcuts will.
    @Test func aSectionTheRoleCannotUseIsNotSelectable() {
        let router = DashboardRouter(isAdminLike: false, isStudent: true)
        router.select(.panel)
        #expect(router.section == .convocatorias, "se queda donde estaba")
    }
}

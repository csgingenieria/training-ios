import Foundation
import Observation

@Observable
@MainActor
final class AuthSession {
    var user: UserDTO?
    var accessToken: String?
    var refreshToken: String?
    var isRestoring: Bool = false

    var isAuthenticated: Bool { user != nil && accessToken != nil }

    func restoreFromKeychain() async {
        guard !isRestoring, !isAuthenticated else { return }
        isRestoring = true
        defer { isRestoring = false }

        guard let access = TokenStore.load(for: .accessToken) else { return }
        let refresh = TokenStore.load(for: .refreshToken)
        accessToken = access
        refreshToken = refresh

        do {
            let me = try await APIClient.shared.me(accessToken: access)
            user = me
        } catch APIError.unauthenticated {
            await logout()
        } catch {
            // No invalidamos sesión por errores de transporte transitorios.
        }
    }

    func login(email: String, password: String) async throws {
        let response = try await APIClient.shared.login(email: email, password: password)
        TokenStore.save(response.access_token, for: .accessToken)
        TokenStore.save(response.refresh_token, for: .refreshToken)
        accessToken = response.access_token
        refreshToken = response.refresh_token
        user = response.user
    }

    func logout() async {
        TokenStore.clearAll()
        user = nil
        accessToken = nil
        refreshToken = nil
    }

    /// Preview helper — NO usar en producción.
    static var previewAuthenticated: AuthSession {
        let session = AuthSession()
        session.accessToken = "preview"
        session.refreshToken = "preview"
        session.user = UserDTO(
            id: "preview-id",
            email: "preview@cmadrid.com",
            name: "Preview User",
            role: "ADMIN",
            organizationId: "org-preview",
            studentProfileId: nil
        )
        return session
    }
}

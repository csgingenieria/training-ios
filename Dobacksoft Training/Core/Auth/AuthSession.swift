import Foundation
import Observation

@Observable
@MainActor
final class AuthSession {
    var user: UserDTO?
    var accessToken: String?
    var refreshToken: String?
    var isRestoring: Bool = false
    var hasRestoredSession: Bool = false

    var isAuthenticated: Bool { user != nil && accessToken != nil }

    func restoreFromKeychain() async {
        guard !isRestoring, !hasRestoredSession else { return }
        isRestoring = true
        defer {
            isRestoring = false
            hasRestoredSession = true
        }

        let access = TokenStore.load(for: .accessToken)
        let refresh = TokenStore.load(for: .refreshToken)

        guard access != nil || refresh != nil else { return }

        accessToken = access
        refreshToken = refresh

        do {
            try await restorePersistedSession(accessToken: access, refreshToken: refresh)
        } catch APIError.unauthenticated {
            await logout()
        } catch {
            // No invalidamos sesión por errores de transporte transitorios.
        }
    }

    func login(email: String, password: String) async throws {
        let response = try await APIClient.shared.login(email: email, password: password)
        persistTokens(accessToken: response.access_token, refreshToken: response.refresh_token)
        user = response.user
        hasRestoredSession = true
    }

    func logout() async {
        TokenStore.clearAll()
        user = nil
        accessToken = nil
        refreshToken = nil
        hasRestoredSession = true
    }

    private func restorePersistedSession(
        accessToken: String?,
        refreshToken: String?
    ) async throws {
        if let accessToken {
            do {
                user = try await APIClient.shared.me(accessToken: accessToken)
                return
            } catch APIError.unauthenticated {
                // Intentamos refresh más abajo si existe refresh token.
            }
        }

        guard let refreshToken else {
            throw APIError.unauthenticated
        }

        let refreshResponse = try await APIClient.shared.refresh(refreshToken: refreshToken)
        persistTokens(accessToken: refreshResponse.access_token, refreshToken: refreshToken)
        user = try await APIClient.shared.me(accessToken: refreshResponse.access_token)
    }

    private func persistTokens(accessToken: String, refreshToken: String) {
        TokenStore.save(accessToken, for: .accessToken)
        TokenStore.save(refreshToken, for: .refreshToken)
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    /// Preview helper — NO usar en producción.
    static var previewAuthenticated: AuthSession {
        let session = AuthSession()
        session.accessToken = "preview"
        session.refreshToken = "preview"
        session.hasRestoredSession = true
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

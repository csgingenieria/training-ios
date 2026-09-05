import Testing
import Foundation
import Security

@testable import Dobacksoft_Training

extension KeychainBacked {
    /// Hits the simulator's real Keychain. Serialised through the parent suite.
    struct TokenStoreTests {
        init() {
            try? TokenStore.clearAll()
        }

        @Test func savedTokenComesBack() throws {
            try TokenStore.save("acc-123", for: .accessToken)
            #expect(try TokenStore.load(for: .accessToken) == "acc-123")
        }

        /// The distinction that was missing: absence is a valid answer, not a fault.
        @Test func missingTokenIsNilNotAnError() throws {
            #expect(try TokenStore.load(for: .refreshToken) == nil)
        }

        @Test func savingTwiceReplacesTheValue() throws {
            try TokenStore.save("first", for: .accessToken)
            try TokenStore.save("second", for: .accessToken)
            #expect(try TokenStore.load(for: .accessToken) == "second")
        }

        @Test func deleteRemovesOnlyTheRequestedKey() throws {
            try TokenStore.save("acc", for: .accessToken)
            try TokenStore.save("ref", for: .refreshToken)

            try TokenStore.delete(for: .accessToken)

            #expect(try TokenStore.load(for: .accessToken) == nil)
            #expect(try TokenStore.load(for: .refreshToken) == "ref")
        }

        /// Deleting something that was never stored is a no-op, not a failure.
        @Test func deletingAbsentKeySucceeds() throws {
            try TokenStore.delete(for: .accessToken)
        }

        @Test func clearAllRemovesBothKeys() throws {
            try TokenStore.save("acc", for: .accessToken)
            try TokenStore.save("ref", for: .refreshToken)

            try TokenStore.clearAll()

            #expect(try TokenStore.load(for: .accessToken) == nil)
            #expect(try TokenStore.load(for: .refreshToken) == nil)
        }

        @Test func failureCarriesTheKeychainStatus() {
            let failure = TokenStore.Failure.keychain(status: errSecAuthFailed, operation: "save")
            #expect(failure.status == errSecAuthFailed)
            #expect("\(failure)".contains("save"))
        }
    }
}

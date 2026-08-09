import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var session: Session?
    @Published var isLoading = true

    private var currentNonce: String?

    private init() {
        Task { await observeAuthState() }
    }

    private func observeAuthState() async {
        for await (event, session) in SupabaseService.shared.client.auth.authStateChanges {
            self.session = session
            if event == .initialSession {
                isLoading = false
            }
        }
    }

    /// Called from `SignInWithAppleButton`'s `onRequest` closure.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Called from `SignInWithAppleButton`'s `onCompletion` closure on success.
    func completeAppleSignIn(_ authorization: ASAuthorization) async throws {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else {
            throw AuthError.invalidCredential
        }

        try await SupabaseService.shared.client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    /// Password itself is never hashed or validated client-side beyond a UI
    /// minimum-length hint — Supabase (GoTrue) hashes and stores it
    /// server-side. Sent over HTTPS to `configuration.url` only.
    func signUp(email: String, password: String) async throws {
        try await SupabaseService.shared.client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await SupabaseService.shared.client.auth.signOut()
    }

    enum AuthError: Error {
        case invalidCredential
    }

    private static func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "Unable to generate secure nonce")

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

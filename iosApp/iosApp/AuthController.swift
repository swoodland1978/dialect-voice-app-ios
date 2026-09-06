import Foundation
import AuthenticationServices
import CryptoKit

// Sign in with Apple -> Firebase ID token, without the Firebase SDK.
//
// 1. SignInWithAppleButton (see SignInView) gives us an Apple identity token (a JWT).
// 2. We exchange it at Firebase's Identity Toolkit REST endpoint (accounts:signInWithIdp)
//    for a Firebase ID token + refresh token.
// 3. The ID token is cached and refreshed before expiry; ChatViewModel hands the cached
//    value to the shared module's makeChatApiClient provider.
//
// Requires GoogleService-Info.plist (see FirebaseConfig) AND the Apple provider enabled in
// the Firebase console. Without those, the Apple step still completes and flips to
// .signedIn, but currentIdToken stays nil (backend calls then fail as unauthenticated).
@MainActor
final class AuthController: ObservableObject {
    enum State: Equatable { case signedOut, signingIn, signedIn }

    @Published private(set) var state: State = .signedOut
    @Published private(set) var errorMessage: String?

    /// Firebase ID token if we have a valid one, else nil. Non-suspending on purpose - the
    /// shared module's provider closure is `() -> String?`; refresh happens out of band.
    private(set) var currentIdToken: String?

    private var refreshToken: String?
    private var expiresAt: Date = .distantPast
    private var currentNonce: String?

    var displayName: String?

    // MARK: - Apple button hooks

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        state = .signingIn
        errorMessage = nil
    }

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                state = .signedOut
            } else {
                errorMessage = error.localizedDescription
                state = .signedOut
            }
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let appleIdToken = String(data: tokenData, encoding: .utf8),
                let rawNonce = currentNonce
            else {
                errorMessage = "Apple sign-in returned no identity token."
                state = .signedOut
                return
            }
            if let name = credential.fullName, let given = name.givenName {
                displayName = [given, name.familyName].compactMap { $0 }.joined(separator: " ")
            }
            Task { await exchangeWithFirebase(appleIdToken: appleIdToken, rawNonce: rawNonce) }
        }
    }

    /// Lets you into the app UI without a real backend token - for testing the screens on the
    /// simulator before GoogleService-Info.plist / the Apple provider are set up.
    func continueWithoutSignIn() {
        currentIdToken = nil
        state = .signedIn
    }

    /// Anonymous Firebase sign-in (Identity Toolkit `signUp` with no credentials). Needs the
    /// Anonymous provider enabled in the console. The backend's onUserCreate seeds a new
    /// anonymous uid with the free trial credit, so this is enough to test AI + voice end to
    /// end without any account. Not a production path (Android deliberately has no anon
    /// fallback - see its AuthManager).
    func signInAnonymously() async {
        guard let config = FirebaseConfig.shared else {
            errorMessage = "No Firebase config - set FirebaseConfig.devApiKey"
            return
        }
        state = .signingIn
        errorMessage = nil
        var req = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(config.apiKey)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["returnSecureToken": true])
        do {
            let json = try await Self.postJSON(req)
            if let id = json["idToken"] as? String {
                currentIdToken = id
                refreshToken = json["refreshToken"] as? String
                let ttl = Double(json["expiresIn"] as? String ?? "3600") ?? 3600
                expiresAt = Date().addingTimeInterval(ttl)
                state = .signedIn
            } else {
                errorMessage = (json["error"] as? [String: Any])?["message"] as? String ?? "Sign-in failed"
                state = .signedOut
            }
        } catch {
            errorMessage = error.localizedDescription
            state = .signedOut
        }
    }

    /// Dev/test sign-in with a Firebase email+password user (Identity Toolkit REST). Needs
    /// FirebaseConfig (API key) and the Email/Password provider enabled. Unlike Sign in with
    /// Apple this needs no Apple Developer Program / provider config, so it's the quickest way
    /// to get a real ID token for testing the AI + voice backend on the simulator.
    func signInWithEmail(_ email: String, password: String) async {
        guard let config = FirebaseConfig.shared else {
            errorMessage = "No Firebase config (GoogleService-Info.plist missing)"
            return
        }
        state = .signingIn
        errorMessage = nil
        var req = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(config.apiKey)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "email": email, "password": password, "returnSecureToken": true,
        ])
        do {
            let json = try await Self.postJSON(req)
            if let id = json["idToken"] as? String {
                currentIdToken = id
                refreshToken = json["refreshToken"] as? String
                let ttl = Double(json["expiresIn"] as? String ?? "3600") ?? 3600
                expiresAt = Date().addingTimeInterval(ttl)
                state = .signedIn
            } else {
                errorMessage = (json["error"] as? [String: Any])?["message"] as? String ?? "Sign-in failed"
                state = .signedOut
            }
        } catch {
            errorMessage = error.localizedDescription
            state = .signedOut
        }
    }

    func signOut() {
        currentIdToken = nil
        refreshToken = nil
        expiresAt = .distantPast
        displayName = nil
        state = .signedOut
    }

    // MARK: - Firebase REST

    /// Call opportunistically (e.g. before sending a message) to keep currentIdToken fresh.
    func refreshIfNeeded() async {
        guard let refreshToken, Date() >= expiresAt.addingTimeInterval(-120),
              let config = FirebaseConfig.shared else { return }
        var req = URLRequest(url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(config.apiKey)")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken)".data(using: .utf8)
        if let json = try? await Self.postJSON(req) {
            if let id = json["id_token"] as? String {
                currentIdToken = id
                self.refreshToken = json["refresh_token"] as? String ?? refreshToken
                let ttl = Double(json["expires_in"] as? String ?? "3600") ?? 3600
                expiresAt = Date().addingTimeInterval(ttl)
            }
        }
    }

    private func exchangeWithFirebase(appleIdToken: String, rawNonce: String) async {
        guard let config = FirebaseConfig.shared else {
            state = .signedIn   // Apple step succeeded; no backend token available yet.
            return
        }
        var req = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(config.apiKey)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "postBody": "id_token=\(appleIdToken)&providerId=apple.com&nonce=\(rawNonce)",
            "requestUri": "https://\(config.authDomain)",
            "returnSecureToken": true,
            "returnIdpCredential": true,
        ])
        do {
            let json = try await Self.postJSON(req)
            if let id = json["idToken"] as? String {
                currentIdToken = id
                refreshToken = json["refreshToken"] as? String
                let ttl = Double(json["expiresIn"] as? String ?? "3600") ?? 3600
                expiresAt = Date().addingTimeInterval(ttl)
                state = .signedIn
            } else {
                errorMessage = (json["error"] as? [String: Any])?["message"] as? String
                    ?? "Sign-in could not be completed."
                state = .signedOut
            }
        } catch {
            errorMessage = error.localizedDescription
            state = .signedOut
        }
    }

    private static func postJSON(_ request: URLRequest) async throws -> [String: Any] {
        let (data, _) = try await URLSession.shared.data(for: request)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

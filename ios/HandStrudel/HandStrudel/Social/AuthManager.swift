import AuthenticationServices
import CryptoKit
import Foundation
import RevenueCat
import Supabase
import UIKit

/// Shared Supabase client for accounts, posts and the feed.
let supabase = SupabaseClient(supabaseURL: SocialConfig.supabaseURL,
                              supabaseKey: SocialConfig.supabaseAnonKey)

/// Owns the signed-in user and their profile.
@MainActor
final class AuthManager: NSObject, ObservableObject {
    static let displayNameLimit = 40
    @Published private(set) var userId: UUID?
    @Published private(set) var email: String?
    @Published private(set) var profile: Profile?
    @Published var errorMessage: String?

    var isSignedIn: Bool { userId != nil }
    /// Signed in, but still needs a username and terms acceptance before posting.
    var needsProfileSetup: Bool { isSignedIn && (profile?.username == nil || profile?.acceptedTermsAt == nil) }

    private var appleNonce: String?
    private var appleContinuation: CheckedContinuation<ASAuthorization, Error>?

    override init() {
        super.init()
        guard SocialConfig.isConfigured else { return }
        Task {
            for await (_, session) in supabase.auth.authStateChanges {
                await apply(session)
            }
        }
    }

    private func apply(_ session: Session?) async {
        guard let session, !session.isExpired else {
            userId = nil; email = nil; profile = nil
            return
        }
        let changed = userId != session.user.id
        userId = session.user.id
        email = session.user.email
        if changed {
            // RevenueCat purchases follow the account across devices.
            _ = try? await Purchases.shared.logIn(session.user.id.uuidString)
            await refreshProfile()
        }
    }

    func refreshProfile() async {
        guard let userId else { return }
        profile = try? await supabase.from("profiles").select()
            .eq("id", value: userId).single().execute().value
    }

    // MARK: Sign in with Apple

    func signInWithApple() async {
        do {
            let nonce = Self.randomNonce()
            appleNonce = nonce
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email]
            request.nonce = Self.sha256(nonce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            let auth = try await withCheckedThrowingContinuation { cont in
                appleContinuation = cont
                controller.performRequests()
            }
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                throw SocialError.message("Apple didn't return a sign-in token.")
            }
            try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: token, nonce: nonce))
        } catch let e as ASAuthorizationError where e.code == .canceled {
            // user backed out
        } catch let e as ASAuthorizationError {
            // Apple's own messages ("error 1000") don't say what to do. These are
            // usually transient (iCloud not reachable yet, first use after install).
            errorMessage = "Sign in with Apple didn't go through (code \(e.code.rawValue)). Please try again."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Email one-time code

    func sendEmailCode(to email: String) async -> Bool {
        do {
            try await supabase.auth.signInWithOTP(email: email.trimmingCharacters(in: .whitespaces))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func verifyEmailCode(_ code: String, email: String) async {
        do {
            try await supabase.auth.verifyOTP(email: email.trimmingCharacters(in: .whitespaces),
                                              token: code.trimmingCharacters(in: .whitespaces),
                                              type: .email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Profile

    /// Sets the username and records terms acceptance. Returns false if the name is taken.
    func completeProfile(username: String) async -> Bool {
        guard let userId else { return false }
        struct Update: Encodable {
            let username: String
            let accepted_terms_at: Date
        }
        do {
            try await supabase.from("profiles")
                .update(Update(username: username, accepted_terms_at: Date()))
                .eq("id", value: userId).execute()
            await refreshProfile()
            return true
        } catch {
            errorMessage = (error as? PostgrestError)?.code == "23505"
                ? "That username is taken." : error.localizedDescription
            return false
        }
    }

    func updateDisplayName(_ displayName: String) async throws {
        guard let userId, var updated = profile, updated.id == userId else {
            throw SocialError.message("Sign in again to edit your profile.")
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.unicodeScalars.count <= Self.displayNameLimit else {
            throw SocialError.message("Use 40 characters or fewer.")
        }
        let displayName = name.isEmpty ? nil : name
        struct Update: Encodable {
            let display_name: String?

            func encode(to encoder: Encoder) throws {
                enum Key: String, CodingKey { case display_name }
                var container = encoder.container(keyedBy: Key.self)
                try container.encode(display_name, forKey: .display_name)
            }
        }
        try await supabase.from("profiles").update(Update(display_name: displayName))
            .eq("id", value: userId).execute()
        guard self.userId == userId, let current = profile, current.id == userId else { return }
        updated = current
        updated.displayName = displayName
        profile = updated
    }

    func updateAvatar(_ jpeg: Data?) async throws {
        guard let userId, profile?.id == userId else {
            throw SocialError.message("Sign in again to edit your profile.")
        }
        struct Result: Decodable { let avatarKey: String? }
        let options = jpeg.map { FunctionInvokeOptions(headers: ["Content-Type": "image/jpeg"], body: $0) }
            ?? FunctionInvokeOptions(method: .delete)
        let result: Result = try await supabase.functions.invoke("profile-avatar", options: options)
        guard self.userId == userId, var updated = profile, updated.id == userId else { return }
        updated.avatarKey = result.avatarKey
        profile = updated
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        _ = try? await Purchases.shared.logOut()
    }

    /// Permanently deletes the account, its videos and files (App Store 5.1.1(v)).
    func deleteAccount() async -> Bool {
        do {
            try await supabase.functions.invoke("delete-account")
            await signOut()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var rng = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars[Int(rng.next() % UInt64(chars.count))] })
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension AuthManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            appleContinuation?.resume(returning: authorization)
            appleContinuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        Task { @MainActor in
            appleContinuation?.resume(throwing: error)
            appleContinuation = nil
        }
    }
}

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    /// Anchors the Apple sheet to the app's key window.
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow)
                ?? scenes.first.map { UIWindow(windowScene: $0) }
                ?? UIWindow()
        }
    }
}

enum SocialError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let m): return m }
    }
}

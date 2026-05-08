import Foundation
import Observation
import FirebaseAuth

/// Observable wrapper around FirebaseAuth. The app is fully usable while
/// signed out — sync simply doesn't run. Sign-in / sign-up are async; UI
/// surfaces `lastError` for inline form messaging.
@Observable
final class AuthService {

    static let shared = AuthService()

    private(set) var uid: String?
    private(set) var email: String?
    private(set) var displayName: String?
    private(set) var isEmailVerified: Bool = false
    private(set) var lastError: String?

    @ObservationIgnored private var listenerHandle: AuthStateDidChangeListenerHandle?

    /// Hook the app installs once at boot. Fires whenever auth state flips
    /// (initial restore, sign-in, sign-out, token refresh). Used to start
    /// and stop `WarrantySyncService`.
    @ObservationIgnored var onAuthStateChanged: ((String?) -> Void)?

    var isSignedIn: Bool { uid != nil }

    private init() {
        if let user = Auth.auth().currentUser {
            self.uid = user.uid
            self.email = user.email
            self.displayName = user.displayName
            self.isEmailVerified = user.isEmailVerified
        }
        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.uid = user?.uid
            self.email = user?.email
            self.displayName = user?.displayName
            self.isEmailVerified = user?.isEmailVerified ?? false
            self.onAuthStateChanged?(user?.uid)
        }
    }

    deinit {
        if let listenerHandle {
            Auth.auth().removeStateDidChangeListener(listenerHandle)
        }
    }

    func signUp(name: String, email: String, password: String) async {
        lastError = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = trimmedName
                try await change.commitChanges()
                // The auth state listener fires before profile commit completes,
                // so reflect the new name immediately for the UI.
                self.displayName = trimmedName
            }
            // Send the verification email automatically — the user can resend
            // from the Profile banner if it didn't arrive.
            try? await result.user.sendEmailVerification()
        } catch {
            lastError = friendlyMessage(for: error)
        }
    }

    func signIn(email: String, password: String) async {
        lastError = nil
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            lastError = friendlyMessage(for: error)
        }
    }

    func signOut() {
        lastError = nil
        try? Auth.auth().signOut()
    }

    /// Trigger Firebase to send a password-reset email. Returns true on
    /// success so the caller can show a confirmation message; on failure
    /// `lastError` carries a user-readable reason.
    @discardableResult
    func sendPasswordReset(email: String) async -> Bool {
        lastError = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return true
        } catch {
            lastError = friendlyMessage(for: error)
            return false
        }
    }

    /// Re-send the email-verification link to the current user.
    @discardableResult
    func resendEmailVerification() async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        lastError = nil
        do {
            try await user.sendEmailVerification()
            return true
        } catch {
            lastError = friendlyMessage(for: error)
            return false
        }
    }

    /// Pull the latest profile from Firebase. `isEmailVerified` is cached
    /// locally and only refreshes when explicitly asked — call this after
    /// the user clicks the verification link in their inbox.
    func refreshVerificationStatus() async {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.reload()
            self.isEmailVerified = user.isEmailVerified
        } catch {
            lastError = friendlyMessage(for: error)
        }
    }

    /// Map FirebaseAuth's NSError codes to copy a user can act on.
    private func friendlyMessage(for error: Error) -> String {
        let nsErr = error as NSError
        if let code = AuthErrorCode(rawValue: nsErr.code) {
            switch code {
            case .invalidEmail:       return "That email looks invalid."
            case .emailAlreadyInUse:  return "An account already exists for that email."
            case .weakPassword:       return "Pick a stronger password (at least 6 characters)."
            case .wrongPassword,
                 .invalidCredential,
                 .userNotFound:       return "Email or password didn't match."
            case .networkError:       return "Network error — check your connection."
            default:                  break
            }
        }
        return error.localizedDescription
    }
}

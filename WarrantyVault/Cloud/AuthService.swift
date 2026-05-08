import Foundation
import Observation
import FirebaseAuth


@Observable
final class AuthService {

    static let shared = AuthService()

    private(set) var uid: String?
    private(set) var email: String?
    private(set) var displayName: String?
    private(set) var isEmailVerified: Bool = false
    private(set) var lastError: String?

    @ObservationIgnored private var listenerHandle: AuthStateDidChangeListenerHandle?


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


                self.displayName = trimmedName
            }


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


    func refreshVerificationStatus() async {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.reload()
            self.isEmailVerified = user.isEmailVerified
        } catch {
            lastError = friendlyMessage(for: error)
        }
    }


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

import SwiftUI

enum AppFlowStage: Hashable {
    case splash
    case onboarding
    case authentication      // email login gate (first sign-in / after sign-out)
    case biometricLock       // returning user — Face ID re-unlock over a restored session
    case mainApp
}

@Observable
final class AppCoordinator {
    var stage: AppFlowStage = .splash

    private static let onboardingKey = "hasCompletedOnboarding"
    private static let biometricsKey = "biometricsEnabled"

    /// Persisted in UserDefaults — onboarding runs only once per install.
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Self.onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.onboardingKey) }
    }

    /// Mirrors the Profile toggle. Defaults to true when never set, so a
    /// fresh install gets the secure-by-default biometric re-lock.
    private var biometricsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.biometricsKey) as? Bool ?? true
    }

    /// Called by `SplashView` after its animation finishes. A restored
    /// Firebase session sends the user through the biometric re-lock so a
    /// stolen-but-unlocked phone doesn't expose the vault — unless the user
    /// has explicitly disabled it from Profile, in which case we skip
    /// straight to the main app.
    func advanceFromSplash() {
        if AuthService.shared.isSignedIn {
            stage = biometricsEnabled ? .biometricLock : .mainApp
        } else if hasCompletedOnboarding {
            stage = .authentication
        } else {
            stage = .onboarding
        }
    }

    /// Called by `OnboardingContainerView` on completion. Onboarding always
    /// hands off to login (a fresh-install user can't be signed in yet).
    func completeOnboarding() {
        hasCompletedOnboarding = true
        stage = AuthService.shared.isSignedIn ? .mainApp : .authentication
    }

    func biometricsUnlocked() {
        stage = .mainApp
    }

    /// Called by `RootView` whenever Firebase's auth state flips. Sign-in
    /// bypasses the biometric step (the user just typed their password —
    /// re-prompting for a face scan would be redundant). Sign-out from any
    /// post-login stage drops the user back to the email gate.
    func applyAuthState(isSignedIn: Bool) {
        switch stage {
        case .authentication where isSignedIn:
            stage = .mainApp
        case .biometricLock where !isSignedIn,
             .mainApp where !isSignedIn:
            stage = .authentication
        default:
            break
        }
    }

    /// Sign out: ends the Firebase session. The auth-state listener will
    /// flip the stage back to `.authentication`, but we set it eagerly to
    /// avoid a one-frame flicker.
    func signOut() {
        AuthService.shared.signOut()
        stage = .authentication
    }
}

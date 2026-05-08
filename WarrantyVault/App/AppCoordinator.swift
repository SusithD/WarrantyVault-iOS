//
//  AppCoordinator.swift
//  WarrantyVault
//
//  Drives the top-level flow: Splash → Onboarding → Login → MainApp.
//
//  Authentication is provided by Firebase email/password. The session
//  persists across launches via the FirebaseAuth keychain, so signed-in
//  users skip onboarding/login on subsequent launches.
//

import SwiftUI

enum AppFlowStage: Hashable {
    case splash
    case onboarding
    case authentication
    case mainApp
}

@Observable
final class AppCoordinator {
    var stage: AppFlowStage = .splash

    private static let onboardingKey = "hasCompletedOnboarding"

    /// Persisted in UserDefaults — onboarding runs only once per install.
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Self.onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.onboardingKey) }
    }

    /// Called by `SplashView` after its animation finishes. Picks the right
    /// next stage based on whether the user has onboarded and whether
    /// Firebase has restored a session.
    func advanceFromSplash() {
        if AuthService.shared.isSignedIn {
            stage = .mainApp
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

    /// Called by `RootView` whenever Firebase's auth state flips. Bounces
    /// between login and main app to keep the gate honest.
    func applyAuthState(isSignedIn: Bool) {
        switch stage {
        case .authentication where isSignedIn:
            stage = .mainApp
        case .mainApp where !isSignedIn:
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

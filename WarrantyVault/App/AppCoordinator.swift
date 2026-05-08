import SwiftUI

enum AppFlowStage: Hashable {
    case splash
    case onboarding
    case authentication
    case biometricLock
    case mainApp
}

@Observable
final class AppCoordinator {
    var stage: AppFlowStage = .splash

    private static let onboardingKey = "hasCompletedOnboarding"
    private static let biometricsKey = "biometricsEnabled"


    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Self.onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.onboardingKey) }
    }


    private var biometricsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.biometricsKey) as? Bool ?? true
    }


    func advanceFromSplash() {
        if AuthService.shared.isSignedIn {
            stage = biometricsEnabled ? .biometricLock : .mainApp
        } else if hasCompletedOnboarding {
            stage = .authentication
        } else {
            stage = .onboarding
        }
    }


    func completeOnboarding() {
        hasCompletedOnboarding = true
        stage = AuthService.shared.isSignedIn ? .mainApp : .authentication
    }

    func biometricsUnlocked() {
        stage = .mainApp
    }


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


    func signOut() {
        AuthService.shared.signOut()
        stage = .authentication
    }
}

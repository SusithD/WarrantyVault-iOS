import SwiftUI
import CoreData

@main
struct WarrantyVaultApp: App {
    private let persistence = PersistenceController.shared

    @State private var coordinator = AppCoordinator()
    @State private var store: AppStore

    init() {
        FirebaseSetup.configure()
        _store = State(initialValue: AppStore(context: PersistenceController.shared.viewContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.viewContext)
                .environment(coordinator)
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var auth = AuthService.shared

    var body: some View {
        ZStack {
            switch coordinator.stage {
            case .splash:
                SplashView(onFinish: { coordinator.advanceFromSplash() })
                    .transition(.opacity)

            case .onboarding:
                OnboardingContainerView(onComplete: { coordinator.completeOnboarding() })
                    .transition(.opacity)

            case .authentication:
                LoginView()
                    .transition(.opacity)

            case .biometricLock:
                AuthenticationView(onAuthenticated: { coordinator.biometricsUnlocked() })
                    .transition(.opacity)

            case .mainApp:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.stage)
        .task {
            await NotificationService.shared.requestAuthorizationIfNeeded()
        }
        // React to FirebaseAuth state changes — sign-in advances past the
        // gate; sign-out bounces back to it.
        .onChange(of: auth.isSignedIn) { _, signedIn in
            coordinator.applyAuthState(isSignedIn: signedIn)
        }
    }
}

#Preview {
    RootView()
        .environment(AppCoordinator())
}

//
//  WarrantyVaultApp.swift
//  WarrantyVault
//
//  App entry point. Hosts the AppCoordinator and switches between
//  splash, onboarding, auth and main app based on current stage.
//

import SwiftUI
import CoreData

@main
struct WarrantyVaultApp: App {
    private let persistence = PersistenceController.shared

    @State private var coordinator = AppCoordinator()
    @State private var store: AppStore

    init() {
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
                AuthenticationView(onAuthenticated: { coordinator.authenticated() })
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
    }
}

#Preview {
    RootView()
        .environment(AppCoordinator())
}

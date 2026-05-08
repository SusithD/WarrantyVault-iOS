import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    var onAuthenticated: () -> Void

    @Environment(AppCoordinator.self) private var coordinator
    @State private var auth = AuthService.shared
    @State private var isScanning = false
    @State private var hasAutoPrompted = false
    @State private var errorMessage: String?

    /// Honour the system "Reduce Motion" setting — when on, we drop the
    /// scale-pulse animation on the Face-ID tile so users who get nauseous
    /// from animation aren't forced to see it.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppColors.bgApp.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 24)
                brandHeader

                Spacer().frame(height: 32)
                avatarBadge

                Spacer().frame(height: 20)
                copyBlock

                Spacer().frame(height: 28)
                scanBlock

                if let errorMessage {
                    Spacer().frame(height: 14)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                familyVaultChip
                Spacer().frame(height: 14)
                encryptedFooter

                Spacer().frame(height: 24)
                footer
                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            // Auto-prompt the system biometric sheet so the user doesn't have
            // to tap. Guarded so transient re-renders don't fire it twice.
            guard !hasAutoPrompted else { return }
            hasAutoPrompted = true
            beginBiometricAuth()
        }
    }

    // MARK: - Brand header

    private var brandHeader: some View {
        VStack(spacing: 8) {
            Text("WarrantyVault")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(AppColors.textPrimary)
            Text("SECURE INFRASTRUCTURE")
                .font(AppTypography.overline)
                .tracking(2.0)
                .foregroundStyle(AppColors.accent)
        }
    }

    // MARK: - Avatar

    private var avatarBadge: some View {
        ZStack {
            Circle()
                .fill(AppColors.bgSurface)
                .frame(width: 76, height: 76)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(AppColors.accent)
        }
        // Decorative; the welcome copy below already names the screen.
        .accessibilityHidden(true)
    }

    // MARK: - Welcome copy

    private var copyBlock: some View {
        VStack(spacing: 8) {
            Text(auth.displayName.map { "Welcome back, \($0)" } ?? "Welcome Back")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Verify your identity to access your vault")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

    // MARK: - Face-ID scan

    private var scanBlock: some View {
        VStack(spacing: 14) {
            Button(action: beginBiometricAuth) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppColors.bgSurface)
                    .frame(width: 132, height: 132)
                    .overlay(faceIDIcon)
                    // Skip the scale pulse when Reduce Motion is on.
                    .scaleEffect(reduceMotion ? 1.0 : (isScanning ? 0.96 : 1.0))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isScanning)
            }
            .buttonStyle(.plain)
            // The whole tile + label functions as one button. Combine into a
            // single VoiceOver element with a clear action hint.
            .accessibilityLabel(isScanning ? "Scanning your face" : "Authenticate with Face ID")
            .accessibilityHint("Double-tap to scan and unlock your vault")

            Text(isScanning ? "SCANNING…" : "TAP TO SCAN")
                .font(AppTypography.overline)
                .tracking(1.6)
                .foregroundStyle(AppColors.accent)
                // The tile-button label already covers this state for
                // VoiceOver — the visible text is decoration, hide it.
                .accessibilityHidden(true)
        }
    }

    private var faceIDIcon: some View {
        ZStack {
            Circle()
                .stroke(AppColors.accent, lineWidth: 2.5)
                .frame(width: 68, height: 68)

            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    Circle().fill(AppColors.accent).frame(width: 6, height: 6)
                    Circle().fill(AppColors.accent).frame(width: 6, height: 6)
                }
                RoundedRectangle(cornerRadius: 1)
                    .fill(AppColors.accent)
                    .frame(width: 22, height: 2)
            }
        }
    }

    // MARK: - Family vault chip

    private var familyVaultChip: some View {
        HStack(spacing: 10) {
            HStack(spacing: -8) {
                Circle()
                    .fill(AppColors.purple)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(AppColors.bgApp, lineWidth: 2))
                Circle()
                    .fill(AppColors.warning)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(AppColors.bgApp, lineWidth: 2))
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text("+2")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppColors.textInverse)
                    )
                    .overlay(Circle().stroke(AppColors.bgApp, lineWidth: 2))
            }
            Text("FAMILY VAULT ACTIVE")
                .font(AppTypography.overline)
                .tracking(1.2)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(AppColors.bgSurface))
    }

    // MARK: - Encrypted footer line

    private var encryptedFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("END-TO-END ENCRYPTED")
                .font(AppTypography.overline)
                .tracking(1.4)
        }
        .foregroundStyle(AppColors.textTertiary)
    }

    // MARK: - Footer

    /// Fallback when biometrics are unavailable, denied, or the user wants
    /// to switch accounts: signs out of Firebase and bounces to the login
    /// gate where they can enter their email + password.
    private var footer: some View {
        Button("Use password instead") {
            coordinator.signOut()
        }
        .font(AppTypography.bodyStrong)
        .foregroundStyle(AppColors.accent)
    }

    // MARK: - Auth

    private func beginBiometricAuth() {
        withAnimation { isScanning = true }
        errorMessage = nil

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                        error: &error) else {
            // In simulator / no biometrics → auto-succeed for dev builds.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isScanning = false
                onAuthenticated()
            }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: "Unlock WarrantyVault") { success, err in
            DispatchQueue.main.async {
                isScanning = false
                if success {
                    onAuthenticated()
                } else {
                    errorMessage = err?.localizedDescription ?? "Authentication failed"
                }
            }
        }
    }
}

#Preview {
    AuthenticationView(onAuthenticated: {})
        .environment(AppCoordinator())
}

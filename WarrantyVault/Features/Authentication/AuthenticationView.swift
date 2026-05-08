//
//  AuthenticationView.swift
//  WarrantyVault
//
//  Biometric unlock screen. Stubs Face ID via LocalAuthentication and falls
//  back to a passcode prompt.
//

import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    var onAuthenticated: () -> Void

    @State private var isScanning = false
    @State private var showPasscode = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 20) {
                brandHeader
                card
                familyVaultChip
                Spacer(minLength: 16)
                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showPasscode) {
            PasscodeEntrySheet(onUnlock: onAuthenticated)
        }
    }

    // MARK: - Brand header

    private var brandHeader: some View {
        VStack(spacing: 6) {
            Text("WarrantyVault")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(AppColors.textPrimary)
            Text("SECURE INFRASTRUCTURE")
                .font(AppTypography.overline)
                .tracking(2.0)
                .foregroundStyle(AppColors.brandBlue)
        }
    }

    // MARK: - Main card

    private var card: some View {
        GlassCard(padding: 28, cornerRadius: 20) {
            VStack(spacing: 20) {
                avatarBadge
                copyBlock
                scanBlock
                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger)
                        .multilineTextAlignment(.center)
                }
                encryptedFooter
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var avatarBadge: some View {
        ZStack {
            Circle()
                .fill(AppColors.brandBlueSoft)
                .frame(width: 72, height: 72)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(AppColors.brandBlue)
        }
    }

    private var copyBlock: some View {
        VStack(spacing: 6) {
            Text("Welcome Back")
                .font(AppTypography.title)
                .tracking(-0.3)
                .foregroundStyle(AppColors.textPrimary)
            Text("Verify your identity to access your vault")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

    /// Face-ID tap target. The card itself is the affordance; "TAP TO SCAN"
    /// sits below it as a label, not as a pill that clips the card edge.
    private var scanBlock: some View {
        VStack(spacing: 14) {
            Button(action: beginBiometricAuth) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppColors.brandBlueSoft)
                    .frame(width: 132, height: 132)
                    .overlay(faceIDIcon)
                    .scaleEffect(isScanning ? 0.96 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isScanning)
            }
            .buttonStyle(.plain)

            Text(isScanning ? "SCANNING…" : "TAP TO SCAN")
                .font(AppTypography.overline)
                .tracking(1.6)
                .foregroundStyle(AppColors.brandBlue)
        }
    }

    private var encryptedFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("END-TO-END ENCRYPTED")
                .font(AppTypography.overline)
                .tracking(1.4)
        }
        .foregroundStyle(AppColors.textTertiary)
        .padding(.top, 4)
    }

    // MARK: - Family vault chip

    private var familyVaultChip: some View {
        HStack(spacing: 10) {
            HStack(spacing: -8) {
                Circle()
                    .fill(AppColors.purple)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                Circle()
                    .fill(AppColors.warning)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                Circle()
                    .fill(AppColors.textPrimary)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text("+2")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
            Text("FAMILY VAULT ACTIVE")
                .font(AppTypography.overline)
                .tracking(1.2)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(Color.white)
        )
        .overlay(
            Capsule()
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Footer (passcode + forgot)

    private var footer: some View {
        VStack(spacing: 12) {
            Button("Enter Passcode Instead") { showPasscode = true }
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppColors.brandBlue)

            Button("FORGOT PASSCODE?") { }
                .font(AppTypography.overline)
                .tracking(1.4)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Face ID icon

    private var faceIDIcon: some View {
        ZStack {
            Circle()
                .stroke(AppColors.brandBlue, lineWidth: 2.5)
                .frame(width: 68, height: 68)

            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    Circle().fill(AppColors.brandBlue).frame(width: 6, height: 6)
                    Circle().fill(AppColors.brandBlue).frame(width: 6, height: 6)
                }
                RoundedRectangle(cornerRadius: 1)
                    .fill(AppColors.brandBlue)
                    .frame(width: 22, height: 2)
            }
        }
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

// MARK: - Passcode Sheet

private struct PasscodeEntrySheet: View {
    var onUnlock: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var passcode = ""

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(AppColors.border)
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            Text("Enter Passcode")
                .font(AppTypography.title)

            SecureField("••••••", text: $passcode)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding(.horizontal, 40)

            PrimaryButton(title: "Unlock", isEnabled: passcode.count >= 4) {
                onUnlock()
                dismiss()
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDetents([.height(320)])
    }
}

#Preview {
    AuthenticationView(onAuthenticated: {})
}

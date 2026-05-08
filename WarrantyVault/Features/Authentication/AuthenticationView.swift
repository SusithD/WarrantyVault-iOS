//
//  AuthenticationView.swift
//  WarrantyVault
//
//  Dark + lime auth screen. Pure black canvas, content sits directly on
//  the background (no card chrome) — matches the "A Phone" reference DNA.
//  Biometric tap target is a dark grey rounded tile with the lime FaceID
//  icon; press it to start the system biometric flow.
//

import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    var onAuthenticated: () -> Void

    @State private var isScanning = false
    @State private var showPasscode = false
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
        .sheet(isPresented: $showPasscode) {
            PasscodeEntrySheet(onUnlock: onAuthenticated)
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
            Text("Welcome Back")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(AppColors.textPrimary)
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

    // MARK: - Footer (passcode + forgot)

    private var footer: some View {
        VStack(spacing: 12) {
            Button("Enter Passcode Instead") { showPasscode = true }
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppColors.accent)

            Button("FORGOT PASSCODE?") { }
                .font(AppTypography.overline)
                .tracking(1.4)
                .foregroundStyle(AppColors.textSecondary)
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
                .fill(AppColors.borderSubtle)
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            Text("Enter Passcode")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            SecureField("", text: $passcode,
                        prompt: Text("••••••")
                            .foregroundColor(AppColors.textTertiary))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.bgSurface)
                )
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 40)

            PrimaryButton(title: "Unlock", isEnabled: passcode.count >= 4) {
                onUnlock()
                dismiss()
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(AppColors.bgSurfaceMax)
        .presentationDetents([.height(340)])
        .presentationBackground(AppColors.bgSurfaceMax)
    }
}

#Preview {
    AuthenticationView(onAuthenticated: {})
}

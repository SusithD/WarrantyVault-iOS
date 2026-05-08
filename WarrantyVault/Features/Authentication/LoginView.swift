import SwiftUI


struct LoginView: View {
    @State private var auth = AuthService.shared

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false

    @State private var showResetAlert = false
    @State private var resetEmail = ""
    @State private var resetMessage: String?

    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            AppColors.bgApp.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    branding
                        .padding(.top, 64)
                        .padding(.bottom, 32)

                    headline
                        .padding(.bottom, 24)

                    form
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 40)
                }
            }
            .scrollIndicators(.hidden)
        }
    }


    private var branding: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.accent)
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.textInverse)
            }
            Text("WarrantyVault")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.top, 4)
            Text("SECURE INFRASTRUCTURE")
                .font(AppTypography.overline)
                .tracking(2.0)
                .foregroundStyle(AppColors.accent)
        }
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(mode == .signIn ? "Welcome back" : "Create your vault")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            Text(mode == .signIn
                 ? "Sign in to access your warranties."
                 : "Your warranties, synced and secure.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
        }
        .multilineTextAlignment(.center)
    }

    private var form: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                modeSwitch

                if mode == .signUp {
                    fieldLabel("Name")
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.bgSurface))
                        .foregroundStyle(AppColors.textPrimary)
                }

                fieldLabel("Email")
                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.bgSurface))
                    .foregroundStyle(AppColors.textPrimary)

                fieldLabel("Password")
                SecureField("At least 6 characters", text: $password)
                    .textContentType(mode == .signIn ? .password : .newPassword)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.bgSurface))
                    .foregroundStyle(AppColors.textPrimary)

                if let err = auth.lastError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.danger)
                }

                if let info = resetMessage {
                    Text(info)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.accent)
                }

                PrimaryButton(
                    title: mode == .signIn
                        ? (isWorking ? "Signing in…" : "Sign In")
                        : (isWorking ? "Creating…" : "Create Account"),
                    isEnabled: canSubmit
                ) { submit() }

                if mode == .signIn {
                    Button {
                        resetEmail = email
                        resetMessage = nil
                        showResetAlert = true
                    } label: {
                        Text("Forgot password?")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .alert("Reset password", isPresented: $showResetAlert) {
            TextField("Email", text: $resetEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            Button("Send reset link") { sendReset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll email you a link to reset your password.")
        }
    }


    private var modeSwitch: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases) { m in
                Button {
                    if mode != m {
                        mode = m
                        password = ""
                    }
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(mode == m ? AppColors.textInverse : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(mode == m ? AppColors.accent : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(AppColors.bgSurface))
    }


    private var canSubmit: Bool {
        guard !isWorking, email.contains("@"), password.count >= 6 else { return false }
        if mode == .signUp {
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.textSecondary)
    }

    private func sendReset() {
        let target = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let ok = await auth.sendPasswordReset(email: target)
            if ok {
                resetMessage = "Password reset link sent to \(target). Check your inbox."
            }
        }
    }

    private func submit() {
        let pendingName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingPassword = password
        Task {
            isWorking = true
            switch mode {
            case .signIn:
                await auth.signIn(email: pendingEmail, password: pendingPassword)
            case .signUp:
                await auth.signUp(name: pendingName, email: pendingEmail, password: pendingPassword)
            }
            isWorking = false


        }
    }
}

#Preview {
    LoginView()
}

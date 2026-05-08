import SwiftUI

/// Sheet for cloud-sync sign-in / sign-up. Optional flow — the app works
/// fully offline without ever signing in. When signed in, shows the active
/// account and a sign-out action.
struct CloudSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthService.shared
    @State private var sync = WarrantySyncService.shared

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false

    enum Mode { case signIn, signUp }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if auth.isSignedIn {
                            signedInCard
                        } else {
                            signInCard
                        }
                        infoCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Cloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Signed in

    private var signedInCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(AppColors.accent.opacity(0.15)).frame(width: 44, height: 44)
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed in").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(auth.email ?? "—").font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: sync.isActive ? "arrow.triangle.2.circlepath" : "pause.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(sync.isActive ? AppColors.accent : AppColors.textTertiary)
                    Text(sync.isActive ? "Syncing changes in real time" : "Sync paused")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }

                if let err = sync.lastError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.danger)
                }

                SecondaryButton(title: "Sign out", icon: "rectangle.portrait.and.arrow.right") {
                    auth.signOut()
                }
            }
        }
    }

    // MARK: - Sign in / sign up

    private var signInCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(mode == .signIn ? "Sign In".uppercased() : "Create Account".uppercased())
                    .overlineStyle()

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

                PrimaryButton(
                    title: mode == .signIn ? (isWorking ? "Signing in…" : "Sign In")
                                            : (isWorking ? "Creating…" : "Create Account"),
                    isEnabled: canSubmit
                ) {
                    submit()
                }

                Button {
                    mode = (mode == .signIn ? .signUp : .signIn)
                } label: {
                    Text(mode == .signIn
                         ? "No account? Create one"
                         : "Already have an account? Sign in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var infoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Why sign in?".uppercased()).overlineStyle()
                Text("Cloud sync keeps your warranties and claims in sync across devices, and protects them if you lose this phone. The app keeps working offline; changes upload as soon as you're back online.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !isWorking
        && email.contains("@")
        && password.count >= 6
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.textSecondary)
    }

    private func submit() {
        let pendingEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingPassword = password
        Task {
            isWorking = true
            switch mode {
            case .signIn:  await auth.signIn(email: pendingEmail, password: pendingPassword)
            case .signUp:  await auth.signUp(email: pendingEmail, password: pendingPassword)
            }
            isWorking = false
            if auth.isSignedIn {
                password = ""
            }
        }
    }
}

#Preview {
    CloudSyncView()
}

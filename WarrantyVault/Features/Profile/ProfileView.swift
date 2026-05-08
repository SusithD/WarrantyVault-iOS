import SwiftUI
import UserNotifications

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppCoordinator.self) private var coordinator
    @State private var auth = AuthService.shared
    @AppStorage("notificationsEnabled") private var notificationsOn = true
    @AppStorage("biometricsEnabled")    private var biometricsOn = true

    @State private var verificationStatus: String?
    @State private var isWorkingOnVerification = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                if auth.isSignedIn && !auth.isEmailVerified {
                    verificationBanner
                }
                preferencesCard
                signOutButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .top, spacing: 0) { navBar }
        .task {


            if auth.isSignedIn && !auth.isEmailVerified {
                await auth.refreshVerificationStatus()
            }
        }
    }

    private var verificationBanner: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.warning)
                    Text("Verify your email")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                }
                Text("We sent a link to \(auth.email ?? "your inbox"). Click it to verify your account.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let status = verificationStatus {
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.accent)
                }

                HStack(spacing: 8) {
                    Button {
                        Task {
                            isWorkingOnVerification = true
                            let ok = await auth.resendEmailVerification()
                            verificationStatus = ok ? "Verification email sent." : nil
                            isWorkingOnVerification = false
                        }
                    } label: {
                        Text(isWorkingOnVerification ? "Sending…" : "Resend email")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textInverse)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(AppColors.accent))
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorkingOnVerification)

                    Button {
                        Task {
                            isWorkingOnVerification = true
                            await auth.refreshVerificationStatus()
                            if !auth.isEmailVerified {
                                verificationStatus = "Still not verified — check your inbox."
                            }
                            isWorkingOnVerification = false
                        }
                    } label: {
                        Text("I've verified")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(AppColors.bgSurfaceHi))
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorkingOnVerification)
                }
            }
        }
    }

    private var navBar: some View {
        HStack {
            Text("Profile")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(GradientBackground().opacity(0.95).ignoresSafeArea(edges: .top))
    }

    private var profileCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppColors.brandBlue.opacity(0.25)).frame(width: 60, height: 60)
                    Text(displayInitials)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.brandBlue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(displayEmail)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }
        }
    }


    private var displayName: String {
        if auth.isSignedIn, let name = auth.displayName, !name.isEmpty {
            return name
        }
        if auth.isSignedIn, let email = auth.email {
            return email
        }
        return store.household.members.first?.name ?? "Guest"
    }

    private var displayEmail: String {
        if auth.isSignedIn, let email = auth.email {
            return email
        }
        return store.household.members.first?.email ?? ""
    }

    private var displayInitials: String {
        let source = displayName
        let words = source.split(whereSeparator: { !$0.isLetter })
        let initials = words.prefix(2).compactMap { $0.first.map(String.init) }.joined()
        return initials.uppercased().isEmpty ? "•" : initials.uppercased()
    }

    private var preferencesCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                Toggle(isOn: $notificationsOn) {
                    settingLabel(symbol: "bell.fill", title: "Expiry & claim alerts")
                }
                .tint(AppColors.brandBlue)
                .padding(.vertical, 8)
                .onChange(of: notificationsOn) { _, isOn in
                    Task { await applyNotificationToggle(isOn) }
                }
                Divider()
                Toggle(isOn: $biometricsOn) {
                    settingLabel(symbol: "faceid", title: "Face ID unlock")
                }
                .tint(AppColors.brandBlue)
                .padding(.vertical, 8)
            }
        }
    }


    @MainActor
    private func applyNotificationToggle(_ isOn: Bool) async {
        if isOn {
            _ = await NotificationService.shared.requestAuthorizationIfNeeded()
            for w in store.warranties where w.reminderEnabled {
                await NotificationService.shared.schedule(for: w)
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    private var signOutButton: some View {
        Button {
            coordinator.signOut()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign out")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(AppColors.danger)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(AppColors.dangerSoft))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func settingLabel(symbol: String, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppColors.brandBlueSoft)
                    .frame(width: 30, height: 30)
                Image(systemName: symbol).foregroundStyle(AppColors.brandBlue).font(.system(size: 13, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
        }
    }

}

#Preview {
    ProfileView()
        .environment(AppStore())
        .environment(AppCoordinator())
}

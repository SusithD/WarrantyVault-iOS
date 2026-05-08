import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppCoordinator.self) private var coordinator
    @State private var auth = AuthService.shared
    @State private var notificationsOn = true
    @State private var biometricsOn = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                preferencesCard
                supportCard
                signOutButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .top, spacing: 0) { navBar }
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
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(.orange)
                        Text("Plus member · renews Mar 2027").font(.system(size: 11, weight: .medium)).foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.top, 2)
                }
                Spacer()
            }
        }
    }

    /// Profile header sources name/email from the signed-in Firebase user
    /// when available, falling back to the local household mock so the
    /// offline-only experience still has something to show.
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
                Divider()
                Toggle(isOn: $biometricsOn) {
                    settingLabel(symbol: "faceid", title: "Face ID unlock")
                }
                .tint(AppColors.brandBlue)
                .padding(.vertical, 8)
                Divider()
                actionRow(symbol: "moon.stars.fill", title: "Appearance", trailing: "System")
                Divider()
                actionRow(symbol: "rectangle.and.text.magnifyingglass", title: "Receipts OCR", trailing: "Beta")
            }
        }
    }

    private var supportCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                actionRow(symbol: "questionmark.circle.fill", title: "Help center")
                Divider()
                actionRow(symbol: "star.bubble.fill",         title: "Send feedback")
                Divider()
                actionRow(symbol: "doc.text.fill",            title: "Terms & privacy")
            }
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

    private func actionRow(symbol: String, title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 12) {
            settingLabel(symbol: symbol, title: title)
            Spacer()
            if let trailing {
                Text(trailing).font(.system(size: 12, weight: .medium)).foregroundStyle(AppColors.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
        .environment(AppStore())
        .environment(AppCoordinator())
}

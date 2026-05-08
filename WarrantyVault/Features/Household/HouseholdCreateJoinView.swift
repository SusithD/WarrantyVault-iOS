import SwiftUI

struct HouseholdCreateJoinView: View {
    @Environment(AppStore.self) private var store
    @State private var mode: Mode = .create
    @State private var householdName: String = ""
    @State private var inviteCode: String = ""

    enum Mode: String, CaseIterable, Identifiable {
        case create = "Create"
        case join   = "Join"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(spacing: 18) {
                    heroIllustration
                    intro
                    picker
                    if mode == .create { createCard } else { joinCard }
                    cta
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
    }

    private var heroIllustration: some View {
        ZStack {
            Circle().fill(AppColors.brandBlueSoft).frame(width: 140, height: 140)
            Circle().fill(AppColors.brandBlue.opacity(0.18)).frame(width: 100, height: 100)
            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppColors.brandBlue)
        }
        .padding(.top, 12)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FAMILY VAULT".uppercased()).overlineStyle(color: AppColors.brandBlue)
            Text("Share coverage with the people you live with.")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Create a household or join an existing one with an invite code.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var picker: some View {
        HStack(spacing: 6) {
            ForEach(Mode.allCases) { m in
                Button { mode = m } label: {
                    Text(m.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(mode == m ? AppColors.textInverse : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(mode == m ? AppColors.accent : AppColors.bgSurfaceHi)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var createCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Household name").overlineStyle()
                TextField(
                    "",
                    text: $householdName,
                    prompt: Text("e.g. The Chen Family")
                        .foregroundColor(AppColors.textTertiary)
                )
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.bgSurfaceHi)
                )

                Divider().background(AppColors.borderSubtle)

                featureRow(symbol: "person.2.fill",       title: "Invite up to 8 people")
                featureRow(symbol: "lock.shield.fill",    title: "Role-based access (Owner, Admin, Member, Viewer)")
                featureRow(symbol: "bell.and.waves.left.and.right.fill", title: "Shared expiry and claim alerts")
            }
        }
    }

    private var joinCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Invite code").overlineStyle()
                TextField(
                    "",
                    text: $inviteCode,
                    prompt: Text("e.g. WV-7X42-PR9")
                        .foregroundColor(AppColors.textTertiary)
                )
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.bgSurfaceHi)
                )

                HStack(spacing: 6) {
                    Image(systemName: "info.circle").foregroundStyle(AppColors.textSecondary)
                    Text("Ask the household owner for their 9-character code.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func featureRow(symbol: String, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.brandBlueSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: symbol).foregroundStyle(AppColors.brandBlue).font(.system(size: 13, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var cta: some View {
        PrimaryButton(
            title: mode == .create ? "Create Household" : "Join Household",
            icon: "arrow.right",
            isEnabled: mode == .create
                ? !householdName.trimmingCharacters(in: .whitespaces).isEmpty
                : inviteCode.count >= 6
        ) {
            if mode == .create {
                store.household = Household(
                    name: householdName.trimmingCharacters(in: .whitespaces),
                    inviteCode: generateCode(),
                    members: MockData.household.members
                )
            } else {
                store.household = MockData.household
            }
        }
    }

    private func generateCode() -> String {
        let letters = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
        let part = { (n: Int) in String((0..<n).map { _ in letters.randomElement()! }) }
        return "WV-\(part(4))-\(part(3))"
    }
}

#Preview {
    HouseholdCreateJoinView().environment(AppStore(warranties: [], claims: [], household: Household(name: "", inviteCode: "", members: []), activity: [], messages: []))
}

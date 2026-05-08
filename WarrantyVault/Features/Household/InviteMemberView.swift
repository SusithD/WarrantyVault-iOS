import SwiftUI
import UIKit

struct InviteMemberView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var role: HouseholdRole = .member

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    codeCard
                    emailCard
                    PrimaryButton(
                        title: "Send Invite",
                        icon: "paperplane.fill",
                        isEnabled: !email.isEmpty && email.contains("@")
                    ) {
                        let m = HouseholdMember(
                            name: name.isEmpty ? email.components(separatedBy: "@").first ?? "New Member" : name,
                            email: email,
                            role: role,
                            avatarInitials: initials(from: name.isEmpty ? email : name),
                            accentHex: "#CFE4FF",
                            joinedDate: Date(),
                            itemCount: 0
                        )
                        store.addMember(m)
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Invite")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }.foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INVITE".uppercased()).overlineStyle(color: AppColors.brandBlue)
            Text("Add someone to \(store.household.name).")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var codeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Invite code").overlineStyle()
                HStack {
                    Text(store.household.inviteCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.brandBlue)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = store.household.inviteCode
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.brandBlue)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(AppColors.brandBlueSoft))
                    }
                    .buttonStyle(.plain)
                }
                Text("Anyone with this code can join with Viewer access by default.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var emailCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Send by email").overlineStyle()
                LabeledTextField(label: "Full name", text: $name, placeholder: "Optional")
                LabeledTextField(label: "Email",     text: $email, placeholder: "name@example.com", keyboard: .emailAddress)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Role").overlineStyle()
                    HStack(spacing: 6) {
                        ForEach(HouseholdRole.allCases) { r in
                            Button { role = r } label: {
                                Text(r.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(role == r ? AppColors.textInverse : AppColors.textSecondary)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(
                                        Capsule().fill(role == r ? r.tint : AppColors.bgSurfaceHi)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func initials(from text: String) -> String {
        let parts = text.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(text.prefix(2)).uppercased()
    }
}

#Preview {
    NavigationStack { InviteMemberView() }
        .environment(AppStore())
}

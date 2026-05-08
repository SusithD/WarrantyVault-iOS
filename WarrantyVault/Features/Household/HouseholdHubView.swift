import SwiftUI

struct HouseholdHubView: View {
    @Environment(AppStore.self) private var store
    @State private var segment: Segment = .members
    @State private var presentingSettings = false

    enum Segment: String, CaseIterable, Identifiable {
        case members  = "Members"
        case activity = "Activity"
        var id: String { rawValue }
    }

    var body: some View {
        if store.household.members.isEmpty {
            HouseholdCreateJoinView()
        } else {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        picker
                        switch segment {
                        case .members:  MembersSection()
                        case .activity: ActivitySection()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .safeAreaInset(edge: .top, spacing: 0) { navBar }
                .sheet(isPresented: $presentingSettings) {
                    HouseholdSettingsSheet()
                        .presentationDetents([.medium])
                }
            }
        }
    }

    private var navBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Household")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                Text(store.household.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            Spacer()
            Button {
                presentingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(AppColors.brandBlue)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(AppColors.brandBlueSoft))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Household settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(GradientBackground().opacity(0.95).ignoresSafeArea(edges: .top))
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Invite Code".uppercased()).overlineStyle()
                    Spacer()
                    Text(store.household.inviteCode)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.brandBlue)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(AppColors.brandBlueSoft))
                }
                HStack(spacing: 12) {
                    statTile(value: "\(store.household.members.count)", label: "Members")
                    statTile(value: "\(store.warranties.count)",        label: "Shared items")
                    statTile(value: "\(store.openClaimsCount)",         label: "Open claims")
                }
            }
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(AppColors.textPrimary)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.surfaceMuted.opacity(0.6)))
    }

    private var picker: some View {
        HStack(spacing: 6) {
            ForEach(Segment.allCases) { seg in
                Button { segment = seg } label: {
                    Text(seg.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(segment == seg ? AppColors.textInverse : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(segment == seg ? AppColors.accent : AppColors.bgSurfaceHi)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}


struct MembersSection: View {
    @Environment(AppStore.self) private var store
    @State private var presentingInvite = false

    var body: some View {
        VStack(spacing: 12) {
            Button { presentingInvite = true } label: {
                GlassCard {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(AppColors.brandBlueSoft).frame(width: 40, height: 40)
                            Image(systemName: "person.crop.circle.badge.plus").foregroundStyle(AppColors.brandBlue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Invite a member")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text("Share the invite code or send an email link.")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(AppColors.brandBlue)
                    }
                }
            }
            .buttonStyle(.plain)

            LazyVStack(spacing: 12) {
                ForEach(store.household.members) { member in
                    MemberRow(member: member)
                }
            }
        }
        .sheet(isPresented: $presentingInvite) {
            NavigationStack { InviteMemberView() }
                .presentationDetents([.medium, .large])
        }
    }
}

struct MemberRow: View {
    let member: HouseholdMember
    @Environment(AppStore.self) private var store
    @State private var presentingRoleMenu = false

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(member.accentColor.opacity(0.35)).frame(width: 46, height: 46)
                    Text(member.avatarInitials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.textPrimary)
                    Text(member.email).font(.system(size: 11, weight: .medium)).foregroundStyle(AppColors.textSecondary)
                    HStack(spacing: 6) {
                        roleChip
                        Text("\(member.itemCount) items").font(.system(size: 11, weight: .medium)).foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(.top, 2)
                }
                Spacer()
                Menu {
                    ForEach(HouseholdRole.allCases) { role in
                        Button(role.rawValue) {
                            store.updateMemberRole(member.id, role: role)
                        }
                    }
                    Divider()
                    Button(role: .destructive) { store.removeMember(member.id) } label: {
                        Label("Remove", systemImage: "person.crop.circle.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppColors.surfaceMuted.opacity(0.6)))
                }
            }
        }
    }

    private var roleChip: some View {
        Text(member.role.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(member.role.tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(member.role.tint.opacity(0.12)))
    }
}


struct ActivitySection: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.activity.isEmpty {
            GlassCard {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.brandBlue)
                    Text("No activity yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Adding warranties or filing claims shows up here so the household can keep track.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(store.activity) { entry in
                    ActivityRow(entry: entry)
                }
            }
        }
    }
}

struct ActivityRow: View {
    let entry: ActivityEntry

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(entry.actorAccent.opacity(0.35)).frame(width: 40, height: 40)
                    Text(entry.actorInitials)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: entry.kind.symbolName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(entry.kind.tint)
                        Text(entry.kind.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(entry.kind.tint)
                    }
                    Text(entry.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(entry.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(entry.actorName) · \(entry.occurredAt.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
            }
        }
    }
}

private struct HouseholdSettingsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draftName: String = ""
    @State private var presentingLeaveConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        nameCard
                        inviteCard
                        leaveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Household Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .onAppear { draftName = store.household.name }
            .alert("Leave this household?", isPresented: $presentingLeaveConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) {
                    store.household.members.removeAll()
                    dismiss()
                }
            } message: {
                Text("You'll be returned to the create-or-join screen. Your warranties stay on this device.")
            }
        }
    }

    private var nameCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Household name".uppercased()).overlineStyle()
                TextField("Household name", text: $draftName)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.bgSurface))
                    .foregroundStyle(AppColors.textPrimary)
                PrimaryButton(
                    title: "Save name",
                    isEnabled: !draftName.trimmingCharacters(in: .whitespaces).isEmpty
                              && draftName != store.household.name
                ) {
                    store.household.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }

    private var inviteCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invite code".uppercased()).overlineStyle()
                    Text(store.household.inviteCode)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.brandBlue)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = store.household.inviteCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppColors.bgSurfaceHi))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy invite code")
            }
        }
    }

    private var leaveButton: some View {
        Button(role: .destructive) {
            presentingLeaveConfirm = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Leave household")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(AppColors.danger)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(AppColors.dangerSoft))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

#Preview {
    HouseholdHubView().environment(AppStore())
}

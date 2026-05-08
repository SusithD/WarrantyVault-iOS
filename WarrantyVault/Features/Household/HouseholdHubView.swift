import SwiftUI

/// Top-level household screen. Routes to the Create/Join flow if there are no members,
/// otherwise shows Members + Activity in a segmented layout.
struct HouseholdHubView: View {
    @Environment(AppStore.self) private var store
    @State private var segment: Segment = .members

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
            Image(systemName: "gearshape.fill")
                .foregroundStyle(AppColors.brandBlue)
                .frame(width: 40, height: 40)
                .background(Circle().fill(AppColors.brandBlueSoft))
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

// MARK: - Members

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

// MARK: - Activity

struct ActivitySection: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(store.activity) { entry in
                ActivityRow(entry: entry)
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

#Preview {
    HouseholdHubView().environment(AppStore())
}

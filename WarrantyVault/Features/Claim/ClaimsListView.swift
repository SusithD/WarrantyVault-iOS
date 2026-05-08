import SwiftUI

struct ClaimsListView: View {
    @Environment(AppStore.self) private var store
    @Binding var presentingFileClaim: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                actionCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("RECENT CLAIMS").overlineStyle()
                    if store.claims.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(store.claims) { claim in
                                NavigationLink(value: claim) {
                                    ClaimRow(claim: claim)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .top, spacing: 0) { navBar }
        .navigationDestination(for: Claim.self) { claim in
            ClaimStatusView(claimID: claim.id)
        }
    }

    private var navBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Support")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                Text("Claims")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(GradientBackground().opacity(0.95).ignoresSafeArea(edges: .top))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CLAIMS".uppercased()).overlineStyle(color: AppColors.purple)
            Text("Track every request in one place.")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppColors.brandBlueSoft).frame(width: 56, height: 56)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.brandBlue)
                }
                VStack(spacing: 4) {
                    Text("No claims yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Open a claim from any warranty if something goes wrong — we'll track it through to resolution.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    presentingFileClaim = true
                } label: {
                    Text("File your first claim")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textInverse)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(AppColors.accent))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    private var actionCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppColors.brandBlueSoft).frame(width: 48, height: 48)
                    Image(systemName: "doc.badge.plus")
                        .foregroundStyle(AppColors.brandBlue)
                        .font(.system(size: 18, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("File a new claim")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Attach photos and we'll route it to the right team.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Button {
                    presentingFileClaim = true
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppColors.brandBlue))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ClaimRow: View {
    let claim: Claim

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(claim.referenceCode)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    statusChip
                }
                Text(claim.productName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(claim.issueSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.system(size: 11, weight: .semibold))
                    Text("Updated \(claim.updatedDate.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    private var statusChip: some View {
        Text(claim.status.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(claim.status.tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(claim.status.softTint))
    }
}

#Preview {
    NavigationStack {
        ClaimsListView(presentingFileClaim: .constant(false))
            .environment(AppStore())
    }
}

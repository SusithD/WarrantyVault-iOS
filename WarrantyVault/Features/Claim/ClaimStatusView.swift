import SwiftUI
import PhotosUI

struct ClaimStatusView: View {
    let claimID: UUID
    @Environment(AppStore.self) private var store
    @State private var presentingChat = false
    @State private var evidencePickerItems: [PhotosPickerItem] = []
    @State private var evidenceConfirmation: String?

    private var claim: Claim? {
        store.claims.first(where: { $0.id == claimID })
    }

    var body: some View {
        ZStack {
            GradientBackground()
            if let c = claim {
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard(c)
                        timelineCard(c)
                        issueCard(c)
                        actions(c)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            } else {
                Text("Claim not found")
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presentingChat) {
            if let c = claim {
                NavigationStack { ClaimChatView(claimID: c.id) }
            }
        }
    }

    private func headerCard(_ c: Claim) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(c.referenceCode)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(c.status.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(c.status.tint)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(c.status.softTint))
                }
                Text(c.productName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Label("Filed " + c.filedDate.formatted(date: .abbreviated, time: .omitted),
                          systemImage: "calendar")
                    Label("Updated " + c.updatedDate.formatted(.relative(presentation: .named)),
                          systemImage: "clock")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func timelineCard(_ c: Claim) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("TIMELINE").overlineStyle()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(c.timeline.enumerated()), id: \.element.id) { idx, event in
                        TimelineRow(
                            event: event,
                            isFirst: idx == 0,
                            isLast:  idx == c.timeline.count - 1
                        )
                    }
                }
            }
        }
    }

    private func issueCard(_ c: Claim) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("ISSUE").overlineStyle()
                Text(c.issueSummary)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actions(_ c: Claim) -> some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Chat with Support", icon: "bubble.left.and.bubble.right.fill") {
                presentingChat = true
            }
            PhotosPicker(
                selection: $evidencePickerItems,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Text("UPLOAD MORE EVIDENCE")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(AppColors.brandBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .onChange(of: evidencePickerItems) { _, items in
                guard !items.isEmpty else { return }
                _ = store.appendClaimEvidence(claimID: c.id, photoCount: items.count)
                evidenceConfirmation = items.count == 1
                    ? "Photo attached to claim."
                    : "\(items.count) photos attached to claim."
                evidencePickerItems = []
            }
            if let msg = evidenceConfirmation {
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.success)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: evidenceConfirmation)
    }
}

struct TimelineRow: View {
    let event: ClaimTimelineEvent
    let isFirst: Bool
    let isLast:  Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? .clear : AppColors.border)
                    .frame(width: 2, height: 10)
                ZStack {
                    Circle()
                        .fill(event.isDone ? AppColors.success : AppColors.border)
                        .frame(width: 18, height: 18)
                    if event.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Rectangle()
                    .fill(isLast ? .clear : AppColors.border)
                    .frame(width: 2)
                    .frame(minHeight: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(event.isDone ? AppColors.textPrimary : AppColors.textSecondary)
                    Spacer()
                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }
                Text(event.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.bottom, isLast ? 0 : 18)
        }
    }
}

#Preview {
    NavigationStack {
        ClaimStatusView(claimID: MockData.claims[0].id)
            .environment(AppStore())
    }
}

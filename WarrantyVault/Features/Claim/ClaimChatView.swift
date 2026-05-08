import SwiftUI
import PhotosUI

struct ClaimChatView: View {
    let claimID: UUID
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @FocusState private var focused: Bool
    @State private var attachmentItems: [PhotosPickerItem] = []

    private var claim: Claim? { store.claims.first(where: { $0.id == claimID }) }

    var body: some View {
        ZStack {
            GradientBackground()
            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(store.messages) { msg in
                                ChatBubble(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .onAppear {
                        if let last = store.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: store.messages.count) {
                        if let last = store.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                composer
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var header: some View {
        GlassCard(cornerRadius: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppColors.brandBlueSoft).frame(width: 40, height: 40)
                    Text("SO").font(.system(size: 14, weight: .bold)).foregroundStyle(AppColors.brandBlue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sofia · Support")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    if let c = claim {
                        Text("\(c.referenceCode) · \(c.productName)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(AppColors.success).frame(width: 7, height: 7)
                    Text("Online").font(.system(size: 11, weight: .semibold)).foregroundStyle(AppColors.success)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(AppColors.successSoft))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            PhotosPicker(
                selection: $attachmentItems,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Image(systemName: "paperclip")
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(AppColors.bgSurfaceHi))
            }
            .accessibilityLabel("Attach photo")
            .onChange(of: attachmentItems) { _, items in
                guard !items.isEmpty else { return }
                let count = items.count
                let label = count == 1 ? "📎 Photo attached" : "📎 \(count) photos attached"
                store.appendMessage(label)
                store.appendClaimEvidence(claimID: claimID, photoCount: count)
                attachmentItems = []
            }

            TextField(
                "",
                text: $draft,
                prompt: Text("Message support").foregroundColor(AppColors.textTertiary),
                axis: .vertical
            )
            .focused($focused)
            .font(AppTypography.body)
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppColors.bgSurfaceHi)
            )

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.textInverse)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                      ? AppColors.bgSurfaceHi : AppColors.accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.bgSurface)
        .overlay(
            Rectangle().fill(AppColors.borderSubtle).frame(height: 0.5),
            alignment: .top
        )
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.appendMessage(trimmed)
        draft = ""
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromUser { Spacer(minLength: 40) }
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(message.isFromUser ? AppColors.textInverse : AppColors.textPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(message.isFromUser ? AppColors.accent : AppColors.bgSurfaceHi)
                    )
                Text(message.sentAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textTertiary)
            }
            if !message.isFromUser { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack {
        ClaimChatView(claimID: MockData.claims[0].id)
            .environment(AppStore())
    }
}

import SwiftUI

struct FileClaimView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var preselectedWarranty: Warranty? = nil

    @State private var selectedWarrantyID: UUID?
    @State private var issueCategory: IssueCategory = .malfunction
    @State private var summary: String = ""
    @State private var description: String = ""
    @State private var photosAttached: Int = 0
    @State private var receiptConfirmed: Bool = true

    enum IssueCategory: String, CaseIterable, Identifiable {
        case malfunction = "Malfunction"
        case defect      = "Defect"
        case damage      = "Damage"
        case missingPart = "Missing Part"
        case other       = "Other"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .malfunction: return "bolt.slash.fill"
            case .defect:      return "exclamationmark.triangle.fill"
            case .damage:      return "hammer.fill"
            case .missingPart: return "shippingbox"
            case .other:       return "questionmark.circle.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(spacing: 16) {
                    intro
                    warrantyPicker
                    issueTypeCard
                    summaryCard
                    descriptionCard
                    evidenceCard
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("File a Claim")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .onAppear {
            if selectedWarrantyID == nil {
                selectedWarrantyID = preselectedWarranty?.id ?? store.warranties.first?.id
            }
        }
    }

    // MARK: Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SUPPORT".uppercased()).overlineStyle(color: AppColors.brandBlue)
            Text("Tell us what happened — we'll take it from here.")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var warrantyPicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Which item?").overlineStyle()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.warranties) { w in
                            Button {
                                selectedWarrantyID = w.id
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: w.category.symbolName)
                                        .foregroundStyle(selectedWarrantyID == w.id ? AppColors.textInverse : w.category.tint)
                                    Text(w.productName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(selectedWarrantyID == w.id ? AppColors.textInverse : AppColors.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(
                                    Capsule().fill(selectedWarrantyID == w.id ? AppColors.accent : AppColors.bgSurfaceHi)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var issueTypeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Issue type").overlineStyle()
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(IssueCategory.allCases) { cat in
                        Button {
                            issueCategory = cat
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: cat.symbol)
                                    .foregroundStyle(issueCategory == cat ? AppColors.accent : AppColors.textSecondary)
                                Text(cat.rawValue)
                                    .lineLimit(1)
                                    .foregroundStyle(issueCategory == cat ? AppColors.textPrimary : AppColors.textSecondary)
                                Spacer()
                                if issueCategory == cat {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColors.accent)
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppColors.bgSurfaceHi)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(issueCategory == cat ? AppColors.accent : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Short summary").overlineStyle()
                TextField(
                    "",
                    text: $summary,
                    prompt: Text("e.g. Drum vibration on spin cycle")
                        .foregroundColor(AppColors.textTertiary)
                )
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.bgSurfaceHi)
                )
            }
        }
    }

    private var descriptionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("What happened?").overlineStyle()
                TextEditor(text: $description)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.bgSurfaceHi)
                    )
            }
        }
    }

    private var evidenceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Evidence").overlineStyle()

                Button {
                    if photosAttached < 6 { photosAttached += 1 }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(AppColors.bgApp).frame(width: 36, height: 36)
                            Image(systemName: "photo.on.rectangle")
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Attach photos or video")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text(photosAttached == 0 ? "Up to 6 files" : "\(photosAttached) attached")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AppColors.accent)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.bgSurfaceHi)
                    )
                }
                .buttonStyle(.plain)

                Toggle(isOn: $receiptConfirmed) {
                    Text("Receipt is attached to the warranty")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                }
                .tint(AppColors.accent)
            }
        }
    }

    private var submitButton: some View {
        PrimaryButton(
            title: "Submit Claim",
            icon: "paperplane.fill",
            isEnabled: selectedWarrantyID != nil && !summary.trimmingCharacters(in: .whitespaces).isEmpty
        ) {
            submit()
        }
    }

    private func submit() {
        guard let id = selectedWarrantyID,
              let w = store.warranties.first(where: { $0.id == id }) else { return }
        let ref = "#CLM-\(Calendar.current.component(.year, from: Date()))-\(Int.random(in: 1000...9999))"
        let claim = Claim(
            referenceCode: ref,
            warrantyID: w.id,
            productName: w.productName,
            issueSummary: summary.isEmpty ? issueCategory.rawValue : summary,
            status: .submitted,
            filedDate: Date(),
            updatedDate: Date(),
            timeline: [
                ClaimTimelineEvent(title: "Claim submitted",   subtitle: "Form received",      date: Date(), isDone: true),
                ClaimTimelineEvent(title: "Documents review",  subtitle: "Queued",             date: Date().addingTimeInterval(60*60*4), isDone: false),
                ClaimTimelineEvent(title: "Under review",      subtitle: "Technician review",  date: Date().addingTimeInterval(60*60*24), isDone: false),
                ClaimTimelineEvent(title: "Decision",          subtitle: "Approval or quote",  date: Date().addingTimeInterval(60*60*24*3), isDone: false),
                ClaimTimelineEvent(title: "Completed",         subtitle: "Closed",             date: Date().addingTimeInterval(60*60*24*6), isDone: false)
            ]
        )
        store.addClaim(claim)
        dismiss()
    }
}

#Preview {
    NavigationStack { FileClaimView() }
        .environment(AppStore())
}

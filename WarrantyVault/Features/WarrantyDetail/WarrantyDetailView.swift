import SwiftUI
import MapKit

struct WarrantyDetailView: View {
    let warrantyID: UUID
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var presentingEdit = false
    @State private var presentingFileClaim = false
    @State private var presentingDeleteConfirm = false

    private var warranty: Warranty? {
        store.warranties.first(where: { $0.id == warrantyID })
    }

    var body: some View {
        ZStack {
            GradientBackground()

            if let w = warranty {
                ScrollView {
                    VStack(spacing: 16) {
                        hero(w)
                        coverageCard(w)
                        detailsCard(w)
                        locationCard(w)
                        receiptCard(w)
                        actions(w)
                        notesCard(w)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            } else {
                Text("Warranty not found")
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { presentingEdit = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) { presentingDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 0.5)
                        )
                }
                .accessibilityLabel("More actions")
                .accessibilityHint("Edit or delete this warranty")
            }
        }
        .sheet(isPresented: $presentingEdit) {
            if let w = warranty {
                NavigationStack {
                    AddWarrantyView(editing: w)
                }
            }
        }
        .sheet(isPresented: $presentingFileClaim) {
            if let w = warranty {
                NavigationStack { FileClaimView(preselectedWarranty: w) }
            }
        }
        .alert("Delete this warranty?", isPresented: $presentingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteWarranty(warrantyID)
                dismiss()
            }
        } message: {
            Text("This removes the item from your vault. You can re-add it later.")
        }
    }

    // MARK: Cards

    private func hero(_ w: Warranty) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    IconBadge(
                        symbol: w.category.symbolName,
                        tint: w.category.tint,
                        style: .soft,
                        size: .large
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(w.brand.uppercased())
                            .overlineStyle()
                        Text(w.productName)
                            .font(AppTypography.headline)
                            .tracking(-0.2)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    StatusTag(status: w.status, daysRemaining: w.daysRemaining)
                    Spacer()
                    Text(w.price.formatted(.currency(code: "USD")))
                        .font(AppTypography.monoBold)
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    private func coverageCard(_ w: Warranty) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Coverage").overlineStyle()
                    Spacer()
                    Text("\(Int(w.coverageProgress * 100))%")
                        .font(AppTypography.captionStrong)
                        .foregroundStyle(AppColors.textSecondary)
                }

                CoverageBar(progress: w.coverageProgress, tint: w.status.tint)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PURCHASED")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(AppColors.textTertiary)
                        Text(w.purchaseDate.formatted(date: .abbreviated, time: .omitted))
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("EXPIRES")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(AppColors.textTertiary)
                        Text(w.expiryDate.formatted(date: .abbreviated, time: .omitted))
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
        }
    }

    private func detailsCard(_ w: Warranty) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Details").overlineStyle()
                detailRow("Retailer", value: w.retailer)
                detailRow("Category", value: w.category.rawValue)
                detailRow(
                    "Serial number",
                    value: w.serialNumber.isEmpty ? "—" : w.serialNumber,
                    valueFont: AppTypography.mono
                )
            }
        }
    }

    private func detailRow(_ label: String, value: String, valueFont: Font = AppTypography.captionStrong) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(valueFont)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    @ViewBuilder
    private func locationCard(_ w: Warranty) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Purchase location").overlineStyle()
                    Spacer()
                    if w.coordinate != nil {
                        Button { openInMaps(w) } label: {
                            HStack(spacing: 4) {
                                Text("OPEN IN MAPS")
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(0.8)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9, weight: .heavy))
                            }
                            .foregroundStyle(AppColors.brandBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let coord = w.coordinate {
                    Map(initialPosition: .region(
                        MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )) {
                        Marker(w.retailer.isEmpty ? "Purchased here" : w.retailer, coordinate: coord)
                            .tint(AppColors.brandBlue)
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .allowsHitTesting(false)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                        Text("No location captured")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func openInMaps(_ w: Warranty) {
        guard let coord = w.coordinate else { return }
        let placemark = MKPlacemark(coordinate: coord)
        let item = MKMapItem(placemark: placemark)
        item.name = w.retailer.isEmpty ? w.productName : w.retailer
        item.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coord)
        ])
    }

    private func receiptCard(_ w: Warranty) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconBadge(
                        symbol: w.receiptAttached ? "doc.text.fill" : "doc.text",
                        tint: AppColors.brandBlue,
                        style: .soft,
                        size: .medium
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(receiptHeadline(for: w))
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(w.receiptAttached ? "Saved with this warranty" : "Edit to add one")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                }

                receiptCarousel(for: w)
            }
        }
    }

    @ViewBuilder
    private func receiptCarousel(for w: Warranty) -> some View {
        let pages = w.receiptImages.compactMap { UIImage(data: $0) }
        if pages.count == 1 {
            Image(uiImage: pages[0])
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 0.5)
                )
        } else if pages.count > 1 {
            TabView {
                ForEach(Array(pages.enumerated()), id: \.offset) { _, img in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 0.5)
                        )
                        .padding(.bottom, 28)  // breathing room above page dots
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 360)
        }
    }

    private func receiptHeadline(for w: Warranty) -> String {
        switch w.receiptImages.count {
        case 0: return "No receipt attached"
        case 1: return "Receipt"
        default: return "Receipt · \(w.receiptImages.count) pages"
        }
    }

    private func actions(_ w: Warranty) -> some View {
        HStack(spacing: 10) {
            PrimaryButton(title: "File Claim", icon: "doc.badge.plus") {
                presentingFileClaim = true
            }
            Button {
                presentingEdit = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Edit")
                        .font(AppTypography.button)
                }
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    Capsule().fill(AppColors.bgSurface)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func notesCard(_ w: Warranty) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Notes").overlineStyle()
                Text(w.notes.isEmpty ? "No notes yet." : w.notes)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Coverage bar

/// Custom 4pt-tall coverage progress bar with a subtle background track.
/// Replaces `ProgressView`'s default styling — looks bespoke instead of stock.
///
/// VoiceOver: announces as "Coverage progress, X percent" via the standard
/// `.progressBar` trait so users with screen readers get the numerical value
/// rather than just "image".
struct CoverageBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.border)
                    .frame(height: 4)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, progress)) * geo.size.width, height: 4)
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("Coverage progress")
        .accessibilityValue("\(Int(max(0, min(1, progress)) * 100)) percent used")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    NavigationStack {
        WarrantyDetailView(warrantyID: MockData.warranties[0].id)
            .environment(AppStore())
    }
}

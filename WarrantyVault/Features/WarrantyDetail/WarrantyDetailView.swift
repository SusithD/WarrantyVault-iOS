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
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.brandBlue)
                }
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
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(w.category.tint.opacity(0.18))
                            .frame(width: 56, height: 56)
                        Image(systemName: w.category.symbolName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(w.category.tint)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(w.brand.uppercased())
                            .overlineStyle()
                        Text(w.productName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    StatusChip(status: w.status, daysRemaining: w.daysRemaining)
                    Spacer()
                    Text(w.price.formatted(.currency(code: "USD")))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    private func coverageCard(_ w: Warranty) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coverage".uppercased()).overlineStyle()
                ProgressView(value: w.coverageProgress)
                    .tint(w.status.tint)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Purchased")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                        Text(w.purchaseDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Expires")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                        Text(w.expiryDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
        }
    }

    private func detailsCard(_ w: Warranty) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Details".uppercased()).overlineStyle()
                detailRow("Retailer",       value: w.retailer)
                detailRow("Category",       value: w.category.rawValue)
                detailRow("Serial number",  value: w.serialNumber.isEmpty ? "—" : w.serialNumber)
            }
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    @ViewBuilder
    private func locationCard(_ w: Warranty) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Purchase location".uppercased()).overlineStyle()
                    Spacer()
                    if w.coordinate != nil {
                        Button {
                            openInMaps(w)
                        } label: {
                            Label("Open in Maps", systemImage: "arrow.up.right.square")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.brandBlue)
                        }
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
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .allowsHitTesting(false)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.slash")
                            .foregroundStyle(AppColors.textTertiary)
                        Text("No location captured")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
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
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.brandBlueSoft)
                            .frame(width: 44, height: 44)
                        Image(systemName: w.receiptAttached ? "doc.text.fill" : "doc.text")
                            .foregroundStyle(AppColors.brandBlue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.receiptAttached ? "Receipt" : "No receipt attached")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(w.receiptAttached ? "Saved with this warranty" : "Edit to add one")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                }

                if let data = w.receiptImage, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func actions(_ w: Warranty) -> some View {
        HStack(spacing: 12) {
            PrimaryButton(title: "File Claim", icon: "doc.badge.plus") {
                presentingFileClaim = true
            }
            Button {
                presentingEdit = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("Edit")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.brandBlue)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(AppColors.brandBlueSoft)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func notesCard(_ w: Warranty) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Notes".uppercased()).overlineStyle()
                Text(w.notes.isEmpty ? "No notes yet." : w.notes)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WarrantyDetailView(warrantyID: MockData.warranties[0].id)
            .environment(AppStore())
    }
}

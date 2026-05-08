import SwiftUI
import PhotosUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store

    // MARK: - Scan flow state
    /// True while the source-picker confirmation dialog is on screen.
    @State private var presentingScanSourcePicker = false
    /// True while the system Photos sheet is open.
    @State private var presentingPhotosPicker = false
    /// True while the camera capture sheet is open (real device only).
    @State private var presentingCameraPicker = false
    /// Photos picker output — observed via `.onChange` to start the OCR flow.
    @State private var photosPickerItem: PhotosPickerItem?
    /// True while OCR + prediction are running. Drives the full-screen overlay.
    @State private var isScanning = false
    /// When set, the AddWarrantyView sheet opens with these fields pre-filled.
    /// Using `Identifiable item:` binding so the sheet only opens after a
    /// successful scan — never with a stale empty draft.
    @State private var scannedDraft: Warranty?

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                scanCard
                summaryStrip
                searchField
                categoryChips

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Your warranties")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text("\(store.filteredWarranties.count) ITEMS")
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    if store.filteredWarranties.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.filteredWarranties) { w in
                                NavigationLink(value: w) {
                                    WarrantyRow(warranty: w)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .top, spacing: 0) { navBar }
        .navigationDestination(for: Warranty.self) { w in
            WarrantyDetailView(warrantyID: w.id)
        }
        // -- Scan flow plumbing -----------------------------------------------
        // Source-picker dialog: lets the user choose Library or Camera.
        .confirmationDialog("Scan a receipt", isPresented: $presentingScanSourcePicker, titleVisibility: .visible) {
            Button("Choose from Library") { presentingPhotosPicker = true }
            if DocumentScannerView.isAvailable {
                Button("Scan with Camera") { presentingCameraPicker = true }
            }
            Button("Cancel", role: .cancel) {}
        }
        // System Photos picker — `.images` filter restricts to image assets.
        .photosPicker(isPresented: $presentingPhotosPicker, selection: $photosPickerItem, matching: .images)
        // Document scanner — VisionKit's edge-detecting, perspective-correcting
        // scanner. Hands back a pre-cropped page to the OCR pipeline.
        .fullScreenCover(isPresented: $presentingCameraPicker) {
            DocumentScannerView { image in
                Task { await processScannedImage(image) }
            }
            .ignoresSafeArea()
        }
        // When a Photos asset is loaded, kick off the scan pipeline.
        .onChange(of: photosPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await processScannedImage(image)
                }
                // Reset so re-picking the same image triggers `.onChange` again.
                photosPickerItem = nil
            }
        }
        // Once OCR finishes successfully, present the AddWarranty form
        // with the parsed fields pre-filled.
        .sheet(item: $scannedDraft) { draft in
            NavigationStack {
                AddWarrantyView(prefilled: draft)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Full-screen "Scanning…" overlay during OCR.
        .overlay {
            if isScanning {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(AppColors.accent)
                        Text("Scanning receipt…")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.bgSurface)
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isScanning)
    }

    /// Runs Vision OCR + the category predictor over a picked/captured image,
    /// then opens the AddWarranty form with a pre-filled draft. The image
    /// itself is encoded for storage so it round-trips into the receipt slot
    /// on the warranty without a second pick.
    @MainActor
    private func processScannedImage(_ image: UIImage) async {
        isScanning = true
        defer { isScanning = false }

        // OCR + parse (already non-blocking inside the scanner).
        guard let result = try? await ReceiptScanner.shared.scan(image) else {
            // Even if OCR fails, drop the user into a blank form with the
            // image attached so they can fill it in manually.
            scannedDraft = blankDraft(with: image)
            return
        }

        // Heuristic post-processing: the OCR `purchaseDate` is the receipt's
        // own date if it found one. Default expiry to one year out — typical
        // for consumer warranties — so the user only needs to adjust if the
        // coverage period differs.
        let purchase = result.purchaseDate ?? Date()
        let expiry = Calendar.current.date(byAdding: .year, value: 1, to: purchase) ?? purchase

        let predictedCategory = CategoryPredictor.shared.predict(from: result.rawText) ?? .electronics

        scannedDraft = Warranty(
            productName: result.productName ?? "",
            brand: "",  // brand isn't reliably extractable; user fills it
            category: predictedCategory,
            purchaseDate: purchase,
            expiryDate: expiry,
            retailer: result.retailer ?? "",
            price: result.totalPrice ?? 0,
            receiptImage: image.receiptEncoded()
        )
    }

    /// Fallback when OCR fails — empty draft, but with the image already
    /// attached so the manual flow doesn't lose what the user picked.
    private func blankDraft(with image: UIImage) -> Warranty {
        Warranty(
            productName: "",
            brand: "",
            category: .electronics,
            purchaseDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
            retailer: "",
            price: 0,
            receiptImage: image.receiptEncoded()
        )
    }

    // MARK: Subviews

    private var navBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Good morning")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text("WarrantyVault")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(-0.2)
            }
            Spacer()
            Button {
                // placeholder notifications
            } label: {
                IconBadge(
                    symbol: "bell",
                    tint: AppColors.textPrimary,
                    style: .outline,
                    size: .medium
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
            .accessibilityHint("Double-tap to view recent alerts")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            GradientBackground().ignoresSafeArea(edges: .top)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back")
                .overlineStyle(color: AppColors.brandBlue)
            Text("Your coverage,\nat a glance.")
                .font(AppTypography.title)
                .tracking(-0.4)
                .foregroundStyle(AppColors.textPrimary)
                .lineSpacing(2)
                // Allow the headline to shrink at AX5 instead of clipping —
                // 80% retains legibility while keeping the layout intact.
                .minimumScaleFactor(0.8)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome back. Your coverage, at a glance.")
    }

    /// Hero CTA card: opens a Library/Camera dialog and runs OCR + category
    /// prediction on the picked image, then drops the user into a pre-filled
    /// AddWarranty form. Lime fill so it reads as a primary action; sits just
    /// below the welcome header where the eye lands first.
    private var scanCard: some View {
        Button {
            presentingScanSourcePicker = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.bgApp)
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan a receipt")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textInverse)
                    Text("Add a warranty in seconds")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textInverse.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(AppColors.textInverse.opacity(0.7))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.accent)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scan a receipt")
        .accessibilityHint("Double-tap to scan a receipt and create a new warranty automatically")
    }

    private var summaryStrip: some View {
        HStack(spacing: 10) {
            summaryTile(
                title: "Active",
                count: store.activeCount,
                tint: AppColors.success,
                symbol: "checkmark"
            )
            summaryTile(
                title: "Expiring",
                count: store.expiringSoonCount,
                tint: AppColors.warning,
                symbol: "clock"
            )
            summaryTile(
                title: "Open Claims",
                count: store.openClaimsCount,
                tint: AppColors.brandBlue,
                symbol: "doc.text"
            )
        }
    }

    private func summaryTile(title: String, count: Int, tint: Color, symbol: String) -> some View {
        GlassCard(padding: 14, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(symbol: symbol, tint: tint, style: .soft, size: .small)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.6)
                        .foregroundStyle(AppColors.textPrimary)
                        .minimumScaleFactor(0.7)
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(count)")
    }

    private var searchField: some View {
        @Bindable var store = store
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
            TextField(
                "",
                text: $store.searchText,
                prompt: Text("Search by product, brand, retailer")
                    .foregroundColor(AppColors.textTertiary)
            )
            .font(AppTypography.body)
            .foregroundStyle(AppColors.textPrimary)
            if !store.searchText.isEmpty {
                Button { store.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private var categoryChips: some View {
        @Bindable var store = store
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "All", isSelected: store.categoryFilter == nil) {
                    store.categoryFilter = nil
                }
                ForEach(WarrantyCategory.allCases) { cat in
                    chip(title: cat.rawValue, isSelected: store.categoryFilter == cat) {
                        store.categoryFilter = (store.categoryFilter == cat) ? nil : cat
                    }
                }
            }
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.chip)
                .foregroundStyle(isSelected ? AppColors.textInverse : AppColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? AppColors.accent : AppColors.bgSurfaceHi)
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 10) {
                IconBadge(symbol: "tray", tint: AppColors.textTertiary, style: .outline, size: .medium)
                Text("Nothing matches those filters")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Try a different search or clear the category filter.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Row

struct WarrantyRow: View {
    let warranty: Warranty

    var body: some View {
        GlassCard(padding: 14, cornerRadius: 14) {
            HStack(spacing: 12) {
                IconBadge(
                    symbol: warranty.category.symbolName,
                    tint: warranty.category.tint,
                    style: .soft,
                    size: .medium
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(warranty.productName)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(warranty.brand)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text("·")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .accessibilityHidden(true)
                        Text(warranty.category.rawValue)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .lineLimit(1)
                    StatusTag(status: warranty.status, daysRemaining: warranty.daysRemaining)
                        .padding(.top, 1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        // Combine the whole row into one VoiceOver element so the user hears
        // "MacBook Pro, Apple, Electronics, Status: Active, 312 days remaining"
        // as a single utterance, then can swipe to the next row.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(warranty.productName), \(warranty.brand), \(warranty.category.rawValue)")
        .accessibilityHint("Double-tap to view details")
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environment(AppStore())
    }
}

import SwiftUI
import PhotosUI
import CoreLocation
import EventKit

struct AddWarrantyView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss


    let editing: Warranty?

    @State private var productName: String
    @State private var brand: String
    @State private var category: WarrantyCategory
    @State private var retailer: String
    @State private var serial: String
    @State private var notes: String
    @State private var priceText: String
    @State private var purchaseDate: Date
    @State private var expiryDate: Date
    @State private var receiptImages: [Data]
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var presentingCamera = false
    @State private var reminderEnabled: Bool
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var locationLabel: String = ""
    @State private var presentingLocationPicker = false
    @State private var locationDeniedHint = false
    @State private var calendarSyncEnabled: Bool
    @State private var calendarDeniedHint = false
    @State private var isScanningReceipt = false
    @State private var didAutoFillFromReceipt = false
    @State private var categoryWasManuallyPicked: Bool

    private static let calendarSyncDefaultKey = "calendarSyncDefault"


    init(editing: Warranty? = nil, prefilled: Warranty? = nil) {
        self.editing = editing


        let baseline = editing ?? prefilled

        _productName   = State(initialValue: baseline?.productName ?? "")
        _brand         = State(initialValue: baseline?.brand ?? "")
        _category      = State(initialValue: baseline?.category ?? .electronics)
        _retailer      = State(initialValue: baseline?.retailer ?? "")
        _serial        = State(initialValue: baseline?.serialNumber ?? "")
        _notes         = State(initialValue: baseline?.notes ?? "")
        _priceText     = State(initialValue: baseline.map { $0.price > 0 ? String(format: "%.2f", $0.price) : "" } ?? "")
        _purchaseDate  = State(initialValue: baseline?.purchaseDate ?? Date())
        _expiryDate    = State(initialValue: baseline?.expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
        _receiptImages   = State(initialValue: baseline?.receiptImages ?? [])
        _reminderEnabled = State(initialValue: baseline?.reminderEnabled ?? true)
        _latitude        = State(initialValue: baseline?.latitude)
        _longitude       = State(initialValue: baseline?.longitude)


        if let editing {
            _calendarSyncEnabled = State(initialValue: editing.eventIdentifier != nil)
        } else {
            _calendarSyncEnabled = State(initialValue: UserDefaults.standard.bool(forKey: Self.calendarSyncDefaultKey))
        }


        _categoryWasManuallyPicked = State(initialValue: editing != nil || prefilled != nil)


        _didAutoFillFromReceipt = State(initialValue: prefilled != nil)
    }

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(spacing: 16) {
                    productCard
                    categoryCard
                    datesCard
                    purchaseDetailsCard
                    locationCard
                    receiptCard
                    reminderToggle
                    calendarToggle
                    notesField
                    savingButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(editing == nil ? "Add Warranty" : "Edit Warranty")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .fullScreenCover(isPresented: $presentingCamera) {
            DocumentScannerView { images in
                Task { await handlePickedReceipts(images) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $presentingLocationPicker) {
            LocationPickerView(initial: currentCoordinate) { coord in
                latitude  = coord.latitude
                longitude = coord.longitude
                Task { await refreshLocationLabel() }
            }
        }
        .onChange(of: photosPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await handlePickedReceipts([image])
                }
            }
        }
        .task { await refreshLocationLabel() }
        .overlay {
            if isScanningReceipt {
                ZStack {
                    Color.black.opacity(0.30).ignoresSafeArea()
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Scanning receipt…")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isScanningReceipt)
    }


    @MainActor
    private func handlePickedReceipts(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        receiptImages = images.compactMap { $0.receiptEncoded() }
        if let first = images.first {
            await scanAndAutoFill(first)
        }
    }

    @MainActor
    private func scanAndAutoFill(_ image: UIImage) async {
        isScanningReceipt = true
        defer { isScanningReceipt = false }

        guard let result = try? await ReceiptScanner.shared.scan(image) else { return }

        var didFill = false
        if productName.trimmingCharacters(in: .whitespaces).isEmpty,
           let p = result.productName, !p.isEmpty {
            productName = p
            didFill = true
        }
        if retailer.trimmingCharacters(in: .whitespaces).isEmpty,
           let r = result.retailer, !r.isEmpty {
            retailer = r
            didFill = true
        }
        if priceText.trimmingCharacters(in: .whitespaces).isEmpty,
           let total = result.totalPrice, total > 0 {
            priceText = String(format: "%.2f", total)
            didFill = true
        }
        if let scanned = result.purchaseDate, editing == nil {

            purchaseDate = scanned
            didFill = true
        }


        if !categoryWasManuallyPicked,
           let predicted = CategoryPredictor.shared.predict(from: result.rawText),
           predicted != category {
            category = predicted
            didFill = true
        }

        didAutoFillFromReceipt = didFill
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }


    private var productCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Product".uppercased()).overlineStyle()
                LabeledTextField(label: "Product name", text: $productName, placeholder: "e.g. Samsung QN90C 65\"")
                LabeledTextField(label: "Brand", text: $brand, placeholder: "e.g. Samsung")
                LabeledTextField(label: "Serial number", text: $serial, placeholder: "Optional")
            }
        }
    }

    private var categoryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Category".uppercased()).overlineStyle()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(WarrantyCategory.allCases) { cat in
                            Button {
                                category = cat
                                categoryWasManuallyPicked = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.symbolName).font(.system(size: 12, weight: .bold))
                                    Text(cat.rawValue).font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(category == cat ? AppColors.textInverse : AppColors.textSecondary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(
                                    Capsule().fill(category == cat ? cat.tint : AppColors.bgSurfaceHi)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var datesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coverage".uppercased()).overlineStyle()
                DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                DatePicker("Expiry date",   selection: $expiryDate,   displayedComponents: .date)
            }
            .tint(AppColors.brandBlue)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppColors.textPrimary)
        }
    }

    private var purchaseDetailsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Purchase".uppercased()).overlineStyle()
                LabeledTextField(label: "Retailer", text: $retailer, placeholder: "e.g. Best Buy")
                LabeledTextField(label: "Price (USD)", text: $priceText, placeholder: "0.00", keyboard: .decimalPad)
            }
        }
    }

    private var locationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Purchase location".uppercased()).overlineStyle()

                HStack(spacing: 10) {
                    Image(systemName: currentCoordinate == nil ? "mappin.slash" : "mappin.and.ellipse")
                        .foregroundStyle(AppColors.brandBlue)
                        .frame(width: 22)
                    Text(locationLabel.isEmpty ? "Not set" : locationLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        receiptActionLabel(symbol: "location.fill", text: "Current")
                    }

                    Button {
                        presentingLocationPicker = true
                    } label: {
                        receiptActionLabel(symbol: "map", text: "Pick on map")
                    }

                    if currentCoordinate != nil {
                        Button(role: .destructive) {
                            latitude = nil
                            longitude = nil
                            locationLabel = ""
                        } label: {
                            receiptActionLabel(symbol: "trash", text: "Clear")
                        }
                    }
                }

                if locationDeniedHint {
                    Text("Location is off. Enable it in Settings → Privacy → Location Services → WarrantyVault.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.danger)
                }
            }
        }
    }

    private func useCurrentLocation() async {
        locationDeniedHint = false
        do {
            let location = try await LocationService.shared.requestCurrentLocation()
            latitude  = location.coordinate.latitude
            longitude = location.coordinate.longitude
            await refreshLocationLabel()
        } catch LocationService.Failure.authorizationDenied {
            locationDeniedHint = true
        } catch {

        }
    }

    private func refreshLocationLabel() async {
        guard let coord = currentCoordinate else {
            locationLabel = ""
            return
        }
        let geo = CLGeocoder()
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        if let p = try? await geo.reverseGeocodeLocation(location).first {
            locationLabel = [p.name, p.locality].compactMap { $0 }.joined(separator: ", ")
        } else {
            locationLabel = String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
        }
    }

    private var receiptCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Receipt".uppercased()).overlineStyle()

                receiptPreview

                HStack(spacing: 8) {
                    PhotosPicker(selection: $photosPickerItem, matching: .images) {
                        receiptActionLabel(symbol: "photo.on.rectangle.angled", text: "Library")
                    }

                    if DocumentScannerView.isAvailable {
                        Button {
                            presentingCamera = true
                        } label: {
                            receiptActionLabel(symbol: "doc.viewfinder", text: "Scan")
                        }
                    }

                    if !receiptImages.isEmpty {
                        Button(role: .destructive) {
                            receiptImages = []
                            photosPickerItem = nil
                            didAutoFillFromReceipt = false
                        } label: {
                            receiptActionLabel(symbol: "trash", text: "Remove")
                        }
                    }
                }

                if didAutoFillFromReceipt {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AppColors.brandBlue)
                        Text("Auto-filled from receipt — tap any field to edit.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var receiptPreview: some View {
        if let data = receiptImages.first, let img = UIImage(data: data) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if receiptImages.count > 1 {
                    Text("\(receiptImages.count) pages")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.textInverse)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(AppColors.accent))
                        .padding(10)
                }
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.bgSurfaceHi)
                    .frame(height: 120)
                VStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                    Text("No receipt attached")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func receiptActionLabel(symbol: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(AppColors.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.bgSurfaceHi)
        )
    }

    private var reminderToggle: some View {
        GlassCard {
            Toggle(isOn: $reminderEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Expiry reminders")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Notify 30, 7, and 1 day before expiry.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .tint(AppColors.brandBlue)
        }
    }

    private var calendarToggle: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $calendarSyncEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add to Calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("All-day event with a 9 AM alert.")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .tint(AppColors.brandBlue)
                .onChange(of: calendarSyncEnabled) { _, new in
                    UserDefaults.standard.set(new, forKey: Self.calendarSyncDefaultKey)
                }

                if calendarDeniedHint {
                    Text("Calendar is off. Enable it in Settings → Privacy → Calendars → WarrantyVault.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.danger)
                }
            }
        }
    }

    private var notesField: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes".uppercased()).overlineStyle()
                TextEditor(text: $notes)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.bgSurfaceHi)
                    )
            }
        }
    }

    private var savingButton: some View {
        PrimaryButton(
            title: editing == nil ? "Save Warranty" : "Save Changes",
            icon: "checkmark",
            isEnabled: !productName.trimmingCharacters(in: .whitespaces).isEmpty
        ) {
            Task { await save() }
        }
    }

    private func save() async {
        let price = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let savedId: UUID
        if let old = editing {
            var updated = old
            updated.productName = productName
            updated.brand = brand
            updated.category = category
            updated.retailer = retailer
            updated.serialNumber = serial
            updated.notes = notes
            updated.price = price
            updated.purchaseDate = purchaseDate
            updated.expiryDate = expiryDate
            updated.receiptImages   = receiptImages
            updated.reminderEnabled = reminderEnabled
            updated.latitude        = latitude
            updated.longitude       = longitude
            store.updateWarranty(updated)
            savedId = updated.id
        } else {
            let w = Warranty(
                productName: productName,
                brand: brand,
                category: category,
                purchaseDate: purchaseDate,
                expiryDate: expiryDate,
                retailer: retailer,
                price: price,
                serialNumber: serial,
                notes: notes,
                receiptImages: receiptImages,
                reminderEnabled: reminderEnabled,
                latitude: latitude,
                longitude: longitude
            )
            store.addWarranty(w)
            savedId = w.id
        }


        if calendarSyncEnabled, EKEventStore.authorizationStatus(for: .event) == .denied {
            calendarDeniedHint = true
            return
        }
        await store.applyCalendarSync(for: savedId, enabled: calendarSyncEnabled)
        if calendarSyncEnabled, EKEventStore.authorizationStatus(for: .event) == .denied {
            calendarDeniedHint = true
            return
        }

        dismiss()
    }
}


struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).overlineStyle()
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundColor(AppColors.textTertiary)
            )
            .font(AppTypography.body)
            .foregroundStyle(AppColors.textPrimary)
            .keyboardType(keyboard)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.bgSurfaceHi)
            )
        }
    }
}

#Preview {
    NavigationStack { AddWarrantyView() }
        .environment(AppStore())
}

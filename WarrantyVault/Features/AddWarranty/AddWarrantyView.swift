import SwiftUI
import PhotosUI
import CoreLocation
import EventKit

struct AddWarrantyView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Pass a warranty to edit it; nil creates a new one.
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
    @State private var receiptImage: Data?
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

    private static let calendarSyncDefaultKey = "calendarSyncDefault"

    init(editing: Warranty? = nil) {
        self.editing = editing
        _productName   = State(initialValue: editing?.productName ?? "")
        _brand         = State(initialValue: editing?.brand ?? "")
        _category      = State(initialValue: editing?.category ?? .electronics)
        _retailer      = State(initialValue: editing?.retailer ?? "")
        _serial        = State(initialValue: editing?.serialNumber ?? "")
        _notes         = State(initialValue: editing?.notes ?? "")
        _priceText     = State(initialValue: editing.map { String(format: "%.2f", $0.price) } ?? "")
        _purchaseDate  = State(initialValue: editing?.purchaseDate ?? Date())
        _expiryDate    = State(initialValue: editing?.expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
        _receiptImage    = State(initialValue: editing?.receiptImage)
        _reminderEnabled = State(initialValue: editing?.reminderEnabled ?? true)
        _latitude        = State(initialValue: editing?.latitude)
        _longitude       = State(initialValue: editing?.longitude)

        // Editing existing warranty: derive calendar toggle from whether an event exists.
        // New warranty: read the user's saved default from UserDefaults (off until opted in once).
        if let editing {
            _calendarSyncEnabled = State(initialValue: editing.eventIdentifier != nil)
        } else {
            _calendarSyncEnabled = State(initialValue: UserDefaults.standard.bool(forKey: Self.calendarSyncDefaultKey))
        }
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
        .sheet(isPresented: $presentingCamera) {
            CameraPicker { image in
                receiptImage = image.receiptEncoded()
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
                    await MainActor.run { receiptImage = image.receiptEncoded() }
                }
            }
        }
        .task { await refreshLocationLabel() }
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: Form cards

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
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.symbolName).font(.system(size: 12, weight: .bold))
                                    Text(cat.rawValue).font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(category == cat ? .white : AppColors.textPrimary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Capsule().fill(category == cat ? cat.tint : Color.white))
                                .overlay(Capsule().stroke(category == cat ? .clear : AppColors.border, lineWidth: 1))
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
            // Silent — user can fall back to Pick on map.
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

                    if CameraPicker.isAvailable {
                        Button {
                            presentingCamera = true
                        } label: {
                            receiptActionLabel(symbol: "camera.fill", text: "Camera")
                        }
                    }

                    if receiptImage != nil {
                        Button(role: .destructive) {
                            receiptImage = nil
                            photosPickerItem = nil
                        } label: {
                            receiptActionLabel(symbol: "trash", text: "Remove")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var receiptPreview: some View {
        if let data = receiptImage, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.surfaceMuted.opacity(0.6))
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
        .foregroundStyle(AppColors.brandBlue)
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.brandBlueSoft)
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
                    .font(.system(size: 14))
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.surfaceMuted.opacity(0.4))
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
            updated.receiptImage    = receiptImage
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
                receiptImage: receiptImage,
                reminderEnabled: reminderEnabled,
                latitude: latitude,
                longitude: longitude
            )
            store.addWarranty(w)
            savedId = w.id
        }

        // Reconcile calendar sync. Surface a denied hint if the user wants
        // the event but hasn't granted access — in that case we keep the
        // form open so the user can read the hint instead of dismissing.
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

// MARK: - Labeled text field

struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).overlineStyle()
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .keyboardType(keyboard)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        }
    }
}

#Preview {
    NavigationStack { AddWarrantyView() }
        .environment(AppStore())
}

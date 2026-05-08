import Foundation
import SwiftUI
import CoreLocation

enum WarrantyCategory: String, CaseIterable, Identifiable, Codable {
    case electronics = "Electronics"
    case appliance   = "Appliance"
    case vehicle     = "Vehicle"
    case furniture   = "Furniture"
    case jewelry     = "Jewelry"
    case tools       = "Tools"
    case other       = "Other"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .electronics: return "tv.inset.filled"
        case .appliance:   return "washer"
        case .vehicle:     return "car.fill"
        case .furniture:   return "sofa.fill"
        case .jewelry:     return "sparkles"
        case .tools:       return "wrench.and.screwdriver.fill"
        case .other:       return "shippingbox.fill"
        }
    }

    var tint: Color {
        switch self {
        case .electronics: return .blue
        case .appliance:   return .purple
        case .vehicle:     return .orange
        case .furniture:   return .pink
        case .jewelry:     return .yellow
        case .tools:       return .green
        case .other:       return .gray
        }
    }
}

struct Warranty: Identifiable, Hashable, Codable {
    let id: UUID
    var productName: String
    var brand: String
    var category: WarrantyCategory
    var purchaseDate: Date
    var expiryDate: Date
    var retailer: String
    var price: Double
    var serialNumber: String
    var notes: String
    var receiptImage: Data?
    var reminderEnabled: Bool
    var latitude: Double?
    var longitude: Double?
    var eventIdentifier: String?

    /// Derived from `receiptImage` — kept for one release so views that read
    /// the legacy `receiptAttached` flag continue to compile unchanged.
    var receiptAttached: Bool { receiptImage != nil }

    /// Returns a coordinate when both lat/lon are present, else `nil`.
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    init(
        id: UUID = UUID(),
        productName: String,
        brand: String,
        category: WarrantyCategory,
        purchaseDate: Date,
        expiryDate: Date,
        retailer: String,
        price: Double,
        serialNumber: String = "",
        notes: String = "",
        receiptImage: Data? = nil,
        reminderEnabled: Bool = true,
        latitude: Double? = nil,
        longitude: Double? = nil,
        eventIdentifier: String? = nil
    ) {
        self.id = id
        self.productName = productName
        self.brand = brand
        self.category = category
        self.purchaseDate = purchaseDate
        self.expiryDate = expiryDate
        self.retailer = retailer
        self.price = price
        self.serialNumber = serialNumber
        self.notes = notes
        self.receiptImage = receiptImage
        self.reminderEnabled = reminderEnabled
        self.latitude = latitude
        self.longitude = longitude
        self.eventIdentifier = eventIdentifier
    }

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
    }

    var status: WarrantyStatus {
        let days = daysRemaining
        if days < 0 { return .expired }
        if days <= 30 { return .expiringSoon }
        return .active
    }

    var coverageProgress: Double {
        let total = expiryDate.timeIntervalSince(purchaseDate)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(purchaseDate)
        return max(0, min(1, elapsed / total))
    }
}

enum WarrantyStatus {
    case active, expiringSoon, expired

    var label: String {
        switch self {
        case .active:        return "Active"
        case .expiringSoon:  return "Expiring Soon"
        case .expired:       return "Expired"
        }
    }

    var tint: Color {
        switch self {
        case .active:       return AppColors.success
        case .expiringSoon: return AppColors.warning
        case .expired:      return AppColors.danger
        }
    }

    var softTint: Color {
        switch self {
        case .active:       return AppColors.successSoft
        case .expiringSoon: return AppColors.warningSoft
        case .expired:      return AppColors.dangerSoft
        }
    }
}

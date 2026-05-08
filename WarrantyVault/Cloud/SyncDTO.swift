import Foundation

/// Wire-format DTOs for Firestore. Kept separate from the domain types so
/// the Core Data schema can evolve without breaking interop with already-
/// synced documents (and vice-versa).
///
/// Image bytes ride inline as a base64 string. Receipts are downscaled by
/// `ImageProcessing` before reaching this layer, so the inflated payload
/// stays comfortably under Firestore's 1 MB document limit.

struct WarrantyDTO: Codable {
    var id: String
    var productName: String
    var brand: String
    var category: String
    var purchaseDate: Date
    var expiryDate: Date
    var retailer: String
    var price: Double
    var serialNumber: String
    var notes: String
    var receiptImagesBase64: [String]
    var reminderEnabled: Bool
    var latitude: Double?
    var longitude: Double?
    var updatedAt: Date

    /// Firestore docs cap at ~1 MB. We trim trailing receipt pages until
    /// the encoded payload fits comfortably below that ceiling rather than
    /// refusing to sync the whole warranty. Local Core Data still holds the
    /// full set of pages — only the cloud copy is capped.
    private static let maxReceiptPayloadBytes = 850_000

    init(_ w: Warranty, updatedAt: Date = Date()) {
        self.id = w.id.uuidString
        self.productName = w.productName
        self.brand = w.brand
        self.category = w.category.rawValue
        self.purchaseDate = w.purchaseDate
        self.expiryDate = w.expiryDate
        self.retailer = w.retailer
        self.price = w.price
        self.serialNumber = w.serialNumber
        self.notes = w.notes
        self.receiptImagesBase64 = Self.encodePagesWithinDocLimit(w.receiptImages)
        self.reminderEnabled = w.reminderEnabled
        self.latitude = w.latitude
        self.longitude = w.longitude
        self.updatedAt = updatedAt
    }

    /// Encode pages to base64, dropping pages from the end until the total
    /// fits within Firestore's 1 MB document budget. Drops everything if
    /// even the first page is too large.
    private static func encodePagesWithinDocLimit(_ pages: [Data]) -> [String] {
        var encoded: [String] = []
        var runningBytes = 0
        for page in pages {
            let b64 = page.base64EncodedString()
            if runningBytes + b64.utf8.count > maxReceiptPayloadBytes { break }
            encoded.append(b64)
            runningBytes += b64.utf8.count
        }
        return encoded
    }

    var asWarranty: Warranty? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Warranty(
            id: uuid,
            productName: productName,
            brand: brand,
            category: WarrantyCategory(rawValue: category) ?? .other,
            purchaseDate: purchaseDate,
            expiryDate: expiryDate,
            retailer: retailer,
            price: price,
            serialNumber: serialNumber,
            notes: notes,
            receiptImages: receiptImagesBase64.compactMap { Data(base64Encoded: $0) },
            reminderEnabled: reminderEnabled,
            latitude: latitude,
            longitude: longitude,
            // Calendar event identifiers are device-local and intentionally
            // not synced — a different device wouldn't share the EventKit DB.
            eventIdentifier: nil
        )
    }
}

struct ClaimDTO: Codable {
    var id: String
    var referenceCode: String
    var warrantyID: String
    var productName: String
    var issueSummary: String
    var status: String
    var filedDate: Date
    var updatedDate: Date
    var timeline: [ClaimTimelineEventDTO]

    init(_ c: Claim) {
        self.id = c.id.uuidString
        self.referenceCode = c.referenceCode
        self.warrantyID = c.warrantyID.uuidString
        self.productName = c.productName
        self.issueSummary = c.issueSummary
        self.status = c.status.rawValue
        self.filedDate = c.filedDate
        self.updatedDate = c.updatedDate
        self.timeline = c.timeline.map(ClaimTimelineEventDTO.init)
    }

    var asClaim: Claim? {
        guard let uuid = UUID(uuidString: id),
              let warrantyUUID = UUID(uuidString: warrantyID),
              let claimStatus = ClaimStatus(rawValue: status) else { return nil }
        return Claim(
            id: uuid,
            referenceCode: referenceCode,
            warrantyID: warrantyUUID,
            productName: productName,
            issueSummary: issueSummary,
            status: claimStatus,
            filedDate: filedDate,
            updatedDate: updatedDate,
            timeline: timeline.compactMap(\.asEvent)
        )
    }
}

struct ClaimTimelineEventDTO: Codable {
    var id: String
    var title: String
    var subtitle: String
    var date: Date
    var isDone: Bool

    init(_ e: ClaimTimelineEvent) {
        self.id = e.id.uuidString
        self.title = e.title
        self.subtitle = e.subtitle
        self.date = e.date
        self.isDone = e.isDone
    }

    var asEvent: ClaimTimelineEvent? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return ClaimTimelineEvent(
            id: uuid,
            title: title,
            subtitle: subtitle,
            date: date,
            isDone: isDone
        )
    }
}

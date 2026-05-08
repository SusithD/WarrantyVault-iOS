import Foundation
import CoreData

extension WarrantyEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WarrantyEntity> {
        NSFetchRequest<WarrantyEntity>(entityName: "WarrantyEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var productName: String
    @NSManaged public var brand: String
    @NSManaged public var categoryRaw: String
    @NSManaged public var purchaseDate: Date
    @NSManaged public var expiryDate: Date
    @NSManaged public var retailer: String
    @NSManaged public var price: Double
    @NSManaged public var serialNumber: String
    @NSManaged public var notes: String
    /// Either:
    ///   - JSON-encoded `[Data]` of compressed receipt pages (current format), or
    ///   - raw JPEG bytes for a single-page receipt (legacy, pre-multi-page).
    /// The bridging extension probes the bytes and wraps a legacy single
    /// image in a one-element array transparently — no schema migration
    /// needed.
    @NSManaged public var receiptImage: Data?
    @NSManaged public var reminderEnabled: Bool
    @NSManaged public var latitude: NSNumber?
    @NSManaged public var longitude: NSNumber?
    @NSManaged public var eventIdentifier: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension WarrantyEntity: Identifiable {}

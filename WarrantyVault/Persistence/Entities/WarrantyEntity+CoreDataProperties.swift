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
    @NSManaged public var receiptAttached: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension WarrantyEntity: Identifiable {}

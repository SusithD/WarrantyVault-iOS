import Foundation
import CoreData

extension Warranty {
    /// Build a struct from a managed entity. The entity's stored category is
    /// matched against `WarrantyCategory.rawValue`; unknown values fall back to `.other`.
    init(_ entity: WarrantyEntity) {
        self.init(
            id: entity.id,
            productName: entity.productName,
            brand: entity.brand,
            category: WarrantyCategory(rawValue: entity.categoryRaw) ?? .other,
            purchaseDate: entity.purchaseDate,
            expiryDate: entity.expiryDate,
            retailer: entity.retailer,
            price: entity.price,
            serialNumber: entity.serialNumber,
            notes: entity.notes,
            receiptImage: entity.receiptImage,
            reminderEnabled: entity.reminderEnabled,
            latitude: entity.latitude?.doubleValue,
            longitude: entity.longitude?.doubleValue,
            eventIdentifier: entity.eventIdentifier
        )
    }
}

extension WarrantyEntity {
    /// Copy struct fields onto this entity. Does not save the context.
    /// `createdAt` is preserved on existing rows; `updatedAt` is always bumped.
    func apply(_ value: Warranty) {
        self.id              = value.id
        self.productName     = value.productName
        self.brand           = value.brand
        self.categoryRaw     = value.category.rawValue
        self.purchaseDate    = value.purchaseDate
        self.expiryDate      = value.expiryDate
        self.retailer        = value.retailer
        self.price           = value.price
        self.serialNumber    = value.serialNumber
        self.notes           = value.notes
        self.receiptImage    = value.receiptImage
        self.reminderEnabled = value.reminderEnabled
        self.latitude        = value.latitude.map { NSNumber(value: $0) }
        self.longitude       = value.longitude.map { NSNumber(value: $0) }
        self.eventIdentifier = value.eventIdentifier
        self.updatedAt       = Date()
    }

    /// Inserts a new row or updates the existing one matching `value.id`.
    @discardableResult
    static func upsert(from value: Warranty, in context: NSManagedObjectContext) -> WarrantyEntity {
        let request = WarrantyEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", value.id as CVarArg)
        request.fetchLimit = 1

        let entity = (try? context.fetch(request).first) ?? {
            let new = WarrantyEntity(context: context)
            new.createdAt = Date()
            return new
        }()

        entity.apply(value)
        return entity
    }
}

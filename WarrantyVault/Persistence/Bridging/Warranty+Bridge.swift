import Foundation
import CoreData

extension Warranty {


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
            receiptImages: WarrantyEntity.decodeReceiptImages(entity.receiptImage),
            reminderEnabled: entity.reminderEnabled,
            latitude: entity.latitude?.doubleValue,
            longitude: entity.longitude?.doubleValue,
            eventIdentifier: entity.eventIdentifier
        )
    }
}

extension WarrantyEntity {


    func apply(_ value: Warranty) {
        self.id                = value.id
        self.productName       = value.productName
        self.brand             = value.brand
        self.categoryRaw       = value.category.rawValue
        self.purchaseDate      = value.purchaseDate
        self.expiryDate        = value.expiryDate
        self.retailer          = value.retailer
        self.price             = value.price
        self.serialNumber      = value.serialNumber
        self.notes             = value.notes
        self.receiptImage      = Self.encodeReceiptImages(value.receiptImages)
        self.reminderEnabled   = value.reminderEnabled
        self.latitude          = value.latitude.map { NSNumber(value: $0) }
        self.longitude         = value.longitude.map { NSNumber(value: $0) }
        self.eventIdentifier   = value.eventIdentifier
        self.updatedAt         = Date()
    }


    static func decodeReceiptImages(_ raw: Data?) -> [Data] {
        guard let raw, !raw.isEmpty else { return [] }
        if let arr = try? JSONDecoder().decode([Data].self, from: raw) {
            return arr
        }
        return [raw]
    }

    static func encodeReceiptImages(_ images: [Data]) -> Data? {
        guard !images.isEmpty else { return nil }
        return try? JSONEncoder().encode(images)
    }


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

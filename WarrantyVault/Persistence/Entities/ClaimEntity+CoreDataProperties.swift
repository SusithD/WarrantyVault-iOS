import Foundation
import CoreData

extension ClaimEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClaimEntity> {
        NSFetchRequest<ClaimEntity>(entityName: "ClaimEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var warrantyId: UUID
    @NSManaged public var referenceCode: String
    @NSManaged public var productName: String
    @NSManaged public var statusRaw: String
    @NSManaged public var issueSummary: String
    @NSManaged public var timelineData: Data?
    @NSManaged public var filedAt: Date
    @NSManaged public var updatedAt: Date
}

extension ClaimEntity: Identifiable {}

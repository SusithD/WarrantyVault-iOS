import Foundation
import CoreData

extension ActivityEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ActivityEntity> {
        NSFetchRequest<ActivityEntity>(entityName: "ActivityEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var kindRaw: String
    @NSManaged public var actorName: String
    @NSManaged public var actorInitials: String
    @NSManaged public var actorAccentHex: String
    @NSManaged public var title: String
    @NSManaged public var detail: String
    @NSManaged public var occurredAt: Date
}

extension ActivityEntity: Identifiable {}

import Foundation
import CoreData

extension ActivityEntry {
    init(_ entity: ActivityEntity) {
        self.init(
            id: entity.id,
            kind: ActivityKind(rawValue: entity.kindRaw) ?? .added,
            actorName: entity.actorName,
            actorInitials: entity.actorInitials,
            actorAccentHex: entity.actorAccentHex,
            title: entity.title,
            detail: entity.detail,
            occurredAt: entity.occurredAt
        )
    }
}

extension ActivityEntity {
    func apply(_ value: ActivityEntry) {
        self.id             = value.id
        self.kindRaw        = value.kind.rawValue
        self.actorName      = value.actorName
        self.actorInitials  = value.actorInitials
        self.actorAccentHex = value.actorAccentHex
        self.title          = value.title
        self.detail         = value.detail
        self.occurredAt     = value.occurredAt
    }

    @discardableResult
    static func upsert(from value: ActivityEntry, in context: NSManagedObjectContext) -> ActivityEntity {
        let request = ActivityEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", value.id as CVarArg)
        request.fetchLimit = 1

        let entity = (try? context.fetch(request).first) ?? ActivityEntity(context: context)
        entity.apply(value)
        return entity
    }
}

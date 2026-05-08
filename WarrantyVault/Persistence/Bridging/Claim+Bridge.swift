import Foundation
import CoreData

extension Claim {
    /// Build a struct from a managed entity. Timeline events are deserialised from
    /// the entity's `timelineData` blob; if decoding fails the timeline comes back empty.
    init(_ entity: ClaimEntity) {
        let timeline: [ClaimTimelineEvent] = {
            guard let data = entity.timelineData else { return [] }
            return (try? JSONDecoder.claimDecoder.decode([ClaimTimelineEvent].self, from: data)) ?? []
        }()

        self.init(
            id: entity.id,
            referenceCode: entity.referenceCode,
            warrantyID: entity.warrantyId,
            productName: entity.productName,
            issueSummary: entity.issueSummary,
            status: ClaimStatus(rawValue: entity.statusRaw) ?? .submitted,
            filedDate: entity.filedAt,
            updatedDate: entity.updatedAt,
            timeline: timeline
        )
    }
}

extension ClaimEntity {
    func apply(_ value: Claim) {
        self.id            = value.id
        self.warrantyId    = value.warrantyID
        self.referenceCode = value.referenceCode
        self.productName   = value.productName
        self.statusRaw     = value.status.rawValue
        self.issueSummary  = value.issueSummary
        self.filedAt       = value.filedDate
        self.updatedAt     = value.updatedDate
        self.timelineData  = try? JSONEncoder.claimEncoder.encode(value.timeline)
    }

    @discardableResult
    static func upsert(from value: Claim, in context: NSManagedObjectContext) -> ClaimEntity {
        let request = ClaimEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", value.id as CVarArg)
        request.fetchLimit = 1

        let entity = (try? context.fetch(request).first) ?? ClaimEntity(context: context)
        entity.apply(value)
        return entity
    }
}

private extension JSONEncoder {
    static let claimEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let claimDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

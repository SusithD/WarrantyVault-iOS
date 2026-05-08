import Foundation
import Observation
import CoreData
import WidgetKit


@Observable
final class AppStore {


    var warranties: [Warranty] = []
    var claims:     [Claim]    = []
    var activity:   [ActivityEntry] = []


    var household: Household
    var messages:  [ChatMessage]


    var selectedTab: MainTab = .dashboard
    var searchText: String = ""
    var categoryFilter: WarrantyCategory? = nil


    @ObservationIgnored private let context: NSManagedObjectContext

    init(
        context: NSManagedObjectContext = PersistenceController.shared.viewContext,
        household: Household = MockData.household,
        messages:  [ChatMessage] = MockData.chatMessages
    ) {
        self.context   = context
        self.household = household
        self.messages  = messages
        reloadAll()
        refreshWidgetSnapshot()
        bindCloudSync()
    }


    private func bindCloudSync() {
        let sync = WarrantySyncService.shared
        sync.onWarrantiesChanged = { [weak self] in
            self?.reloadWarranties()
            self?.refreshWidgetSnapshot()
        }
        sync.onClaimsChanged = { [weak self] in
            self?.reloadClaims()
        }

        if let uid = AuthService.shared.uid {
            sync.start(uid: uid, context: context)
        }

        AuthService.shared.onAuthStateChanged = { [weak self] uid in
            guard let self else { return }
            if let uid {
                sync.start(uid: uid, context: self.context)
            } else {
                sync.stop()
            }
        }
    }

    convenience init(
        warranties: [Warranty],
        claims: [Claim],
        household: Household,
        activity: [ActivityEntry],
        messages: [ChatMessage]
    ) {
        let previewContext = PersistenceController(inMemory: true).viewContext
        for w in warranties { WarrantyEntity.upsert(from: w, in: previewContext) }
        for c in claims     { ClaimEntity.upsert(from: c, in: previewContext) }
        for a in activity   { ActivityEntity.upsert(from: a, in: previewContext) }
        try? previewContext.save()

        self.init(context: previewContext, household: household, messages: messages)
    }


    var filteredWarranties: [Warranty] {
        warranties
            .filter { w in
                guard let cat = categoryFilter else { return true }
                return w.category == cat
            }
            .filter { w in
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !q.isEmpty else { return true }
                return w.productName.lowercased().contains(q)
                    || w.brand.lowercased().contains(q)
                    || w.retailer.lowercased().contains(q)
            }
            .sorted { $0.expiryDate < $1.expiryDate }
    }

    var expiringSoonCount: Int { warranties.filter { $0.status == .expiringSoon }.count }
    var activeCount:       Int { warranties.filter { $0.status == .active }.count }
    var expiredCount:      Int { warranties.filter { $0.status == .expired }.count }

    var openClaimsCount: Int {
        claims.filter { $0.status != .completed && $0.status != .rejected }.count
    }


    func addWarranty(_ w: Warranty) {
        WarrantyEntity.upsert(from: w, in: context)

        let entry = ActivityEntry(
            kind: .added,
            actorName: household.members.first?.name ?? "You",
            actorInitials: household.members.first?.avatarInitials ?? "ME",
            actorAccentHex: household.members.first?.accentHex ?? "#0A84FF",
            title: "Added \(w.productName)",
            detail: "\(w.category.rawValue) · \(w.brand)",
            occurredAt: Date()
        )
        ActivityEntity.upsert(from: entry, in: context)

        save()
        reloadWarranties()
        reloadActivity()
        refreshWidgetSnapshot()

        WarrantySyncService.shared.pushWarranty(w)
        Task.detached { await NotificationService.shared.schedule(for: w) }
    }

    func updateWarranty(_ w: Warranty) {
        WarrantyEntity.upsert(from: w, in: context)
        save()
        reloadWarranties()
        refreshWidgetSnapshot()

        WarrantySyncService.shared.pushWarranty(w)
        Task.detached {
            NotificationService.shared.cancel(for: w.id)
            await NotificationService.shared.schedule(for: w)
        }
    }

    func deleteWarranty(_ id: UUID) {
        let request = WarrantyEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        var calendarEventId: String?
        if let entity = try? context.fetch(request).first {
            calendarEventId = entity.eventIdentifier
            context.delete(entity)
            save()
        }
        reloadWarranties()
        refreshWidgetSnapshot()

        WarrantySyncService.shared.deleteWarranty(id: id)
        Task.detached { NotificationService.shared.cancel(for: id) }
        if let calendarEventId {
            Task.detached { try? CalendarService.shared.deleteEvent(identifier: calendarEventId) }
        }
    }


    func applyCalendarSync(for warrantyId: UUID, enabled: Bool) async {
        let request = WarrantyEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", warrantyId as CVarArg)
        guard let entity = try? context.fetch(request).first else { return }
        let warranty = Warranty(entity)

        if enabled {
            let newId = try? await CalendarService.shared.upsertEvent(for: warranty)
            if let newId, newId != entity.eventIdentifier {
                entity.eventIdentifier = newId
                save()
                reloadWarranties()
            }
        } else if let existingId = entity.eventIdentifier {
            try? CalendarService.shared.deleteEvent(identifier: existingId)
            entity.eventIdentifier = nil
            save()
            reloadWarranties()
        }
    }


    func addClaim(_ c: Claim) {
        ClaimEntity.upsert(from: c, in: context)

        let entry = ActivityEntry(
            kind: .claimed,
            actorName: household.members.first?.name ?? "You",
            actorInitials: household.members.first?.avatarInitials ?? "ME",
            actorAccentHex: household.members.first?.accentHex ?? "#0A84FF",
            title: "Filed claim \(c.referenceCode)",
            detail: "\(c.productName) · \(c.status.rawValue)",
            occurredAt: Date()
        )
        ActivityEntity.upsert(from: entry, in: context)

        save()
        reloadClaims()
        reloadActivity()

        WarrantySyncService.shared.pushClaim(c)
    }


    @discardableResult
    func appendClaimEvidence(claimID: UUID, photoCount: Int = 1) -> Date? {
        guard let idx = claims.firstIndex(where: { $0.id == claimID }) else { return nil }
        var updated = claims[idx]
        let now = Date()
        let label = photoCount == 1 ? "Photo attached" : "\(photoCount) photos attached"
        updated.timeline.append(
            ClaimTimelineEvent(
                title: "Evidence uploaded",
                subtitle: "\(label) · \(now.formatted(date: .omitted, time: .shortened))",
                date: now,
                isDone: true
            )
        )
        updated.updatedDate = now
        ClaimEntity.upsert(from: updated, in: context)
        save()
        reloadClaims()
        WarrantySyncService.shared.pushClaim(updated)
        return now
    }


    func appendMessage(_ text: String) {
        let msg = ChatMessage(text: text, isFromUser: true, sentAt: Date())
        messages.append(msg)
    }

    func addMember(_ m: HouseholdMember) {
        household.members.append(m)
    }

    func removeMember(_ id: UUID) {
        household.members.removeAll { $0.id == id }
    }

    func updateMemberRole(_ id: UUID, role: HouseholdRole) {
        guard let idx = household.members.firstIndex(where: { $0.id == id }) else { return }
        household.members[idx].role = role
    }


    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            assertionFailure("Failed to save context: \(error)")
        }
    }

    private func reloadAll() {
        reloadWarranties()
        reloadClaims()
        reloadActivity()
    }

    private func reloadWarranties() {
        let request = WarrantyEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WarrantyEntity.expiryDate, ascending: true)]
        let entities = (try? context.fetch(request)) ?? []
        warranties = entities.map(Warranty.init)
    }

    private func reloadClaims() {
        let request = ClaimEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClaimEntity.filedAt, ascending: false)]
        let entities = (try? context.fetch(request)) ?? []
        claims = entities.map(Claim.init)
    }

    private func reloadActivity() {
        let request = ActivityEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityEntity.occurredAt, ascending: false)]
        let entities = (try? context.fetch(request)) ?? []
        activity = entities.map(ActivityEntry.init)
    }


    private func refreshWidgetSnapshot() {
        let candidate = warranties
            .filter { $0.status != .expired }
            .min(by: { $0.expiryDate < $1.expiryDate })

        let snapshot: WidgetSnapshot
        if let next = candidate {
            snapshot = WidgetSnapshot(
                nextWarrantyId: next.id,
                nextProductName: next.productName,
                nextCategoryRaw: next.category.rawValue,
                nextDaysUntilExpiry: next.daysRemaining,
                totalActive: warranties.filter { $0.status != .expired }.count,
                writtenAt: Date()
            )
        } else {
            snapshot = WidgetSnapshot.empty
        }

        WidgetSnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum MainTab: Hashable {
    case dashboard, claims, add, household, profile
}

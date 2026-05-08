import Foundation
import Observation
import CoreData
import WidgetKit

/// Core Data-backed observable store. Views still read `warranties`, `claims`,
/// `activity` etc. as struct arrays — the store keeps them in sync with the
/// underlying `NSManagedObjectContext`.
///
/// `household` and `messages` remain in-memory; only the three persisted
/// entities (Warranty / Claim / Activity) round-trip through Core Data.
@Observable
final class AppStore {

    // MARK: Persisted, read-through arrays

    var warranties: [Warranty] = []
    var claims:     [Claim]    = []
    var activity:   [ActivityEntry] = []

    // MARK: In-memory only (not persisted in this step)

    var household: Household
    var messages:  [ChatMessage]

    // MARK: UI state

    var selectedTab: MainTab = .dashboard
    var searchText: String = ""
    var categoryFilter: WarrantyCategory? = nil

    // MARK: Internals

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
    }

    /// Convenience init used by SwiftUI previews. Spins up an in-memory Core Data
    /// stack, seeds it with the supplied struct arrays, and exposes them as the
    /// initial published state. The on-disk store is not touched.
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

    // MARK: Derived

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

    // MARK: Mutations — Warranty

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

        Task.detached { await NotificationService.shared.schedule(for: w) }
    }

    func updateWarranty(_ w: Warranty) {
        WarrantyEntity.upsert(from: w, in: context)
        save()
        reloadWarranties()
        refreshWidgetSnapshot()

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

        Task.detached { NotificationService.shared.cancel(for: id) }
        if let calendarEventId {
            Task.detached { try? CalendarService.shared.deleteEvent(identifier: calendarEventId) }
        }
    }

    /// Reconciles a warranty's calendar event with the user's intent.
    /// Call after `addWarranty` or `updateWarranty` whenever the form's
    /// "Add to Calendar" toggle could differ from the persisted state.
    /// - When `enabled` is true: creates or updates the event, persists the
    ///   resulting identifier back on the warranty entity.
    /// - When `enabled` is false: deletes any existing event and clears
    ///   the identifier.
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

    // MARK: Mutations — Claim

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
    }

    // MARK: Mutations — Chat / Household (in-memory only)

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

    // MARK: Core Data plumbing

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

    /// Persist a small snapshot of "what's expiring next" to the App Group
    /// container and ask WidgetKit to redraw. Cheap; safe to call after every
    /// mutation. No-op when the App Group container isn't available.
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

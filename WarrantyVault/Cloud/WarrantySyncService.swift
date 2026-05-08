import Foundation
import Observation
import CoreData
import FirebaseFirestore

/// Bidirectional Firestore ↔ Core Data sync, scoped to a single signed-in
/// user. Started by `AppStore` in response to auth-state changes.
///
/// **Loop prevention.** Incoming remote writes set `applyingRemote = true`
/// while applying. The push paths (`pushWarranty`, `pushClaim`, `delete*`)
/// no-op while that flag is set, so changes received from Firestore aren't
/// echoed back as local pushes.
///
/// **Conflict resolution.** Last-write-wins by `updatedAt`. The local
/// entity's `updatedAt` is bumped on every local save by the bridging
/// extensions, so a fresher local value won't be overwritten by stale remote.
///
/// **Threading.** Firestore listener callbacks land on the main queue by
/// default, which matches the Core Data viewContext's queue, so saves are
/// safe without explicit dispatching.
@Observable
final class WarrantySyncService {

    static let shared = WarrantySyncService()

    private(set) var isActive = false
    private(set) var lastError: String?

    /// Called after applying remote warranty changes (added/modified/removed).
    /// Used by `AppStore` to refresh its in-memory `warranties` array.
    @ObservationIgnored var onWarrantiesChanged: (() -> Void)?

    /// Called after applying remote claim changes.
    @ObservationIgnored var onClaimsChanged: (() -> Void)?

    @ObservationIgnored private var uid: String?
    @ObservationIgnored private var context: NSManagedObjectContext?
    @ObservationIgnored private var warrantyListener: ListenerRegistration?
    @ObservationIgnored private var claimListener: ListenerRegistration?
    @ObservationIgnored private var applyingRemote = false

    private init() {}

    /// Begin listening to the signed-in user's Firestore subtree and apply
    /// changes into the supplied Core Data context. Re-callable — stops any
    /// previous listeners first.
    func start(uid: String, context: NSManagedObjectContext) {
        stop()
        self.uid = uid
        self.context = context
        self.isActive = true
        attachWarrantyListener()
        attachClaimListener()
    }

    func stop() {
        warrantyListener?.remove()
        claimListener?.remove()
        warrantyListener = nil
        claimListener = nil
        uid = nil
        context = nil
        isActive = false
    }

    // MARK: - Push (Core Data → Firestore)

    func pushWarranty(_ warranty: Warranty) {
        guard !applyingRemote, let collection = warrantyCollection() else { return }
        let dto = WarrantyDTO(warranty)
        do {
            try collection.document(dto.id).setData(from: dto)
        } catch {
            lastError = "Push failed: \(error.localizedDescription)"
        }
    }

    func deleteWarranty(id: UUID) {
        guard !applyingRemote, let collection = warrantyCollection() else { return }
        collection.document(id.uuidString).delete()
    }

    func pushClaim(_ claim: Claim) {
        guard !applyingRemote, let collection = claimCollection() else { return }
        let dto = ClaimDTO(claim)
        do {
            try collection.document(dto.id).setData(from: dto)
        } catch {
            lastError = "Push failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Pull (Firestore → Core Data)

    private func attachWarrantyListener() {
        guard let collection = warrantyCollection() else { return }
        warrantyListener = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                self.lastError = "Warranty sync error: \(error.localizedDescription)"
                return
            }
            guard let snapshot, !snapshot.documentChanges.isEmpty else { return }
            self.applyingRemote = true
            for change in snapshot.documentChanges {
                self.applyWarrantyChange(change)
            }
            self.applyingRemote = false
            self.onWarrantiesChanged?()
        }
    }

    private func attachClaimListener() {
        guard let collection = claimCollection() else { return }
        claimListener = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                self.lastError = "Claim sync error: \(error.localizedDescription)"
                return
            }
            guard let snapshot, !snapshot.documentChanges.isEmpty else { return }
            self.applyingRemote = true
            for change in snapshot.documentChanges {
                self.applyClaimChange(change)
            }
            self.applyingRemote = false
            self.onClaimsChanged?()
        }
    }

    private func applyWarrantyChange(_ change: DocumentChange) {
        guard let context else { return }
        switch change.type {
        case .added, .modified:
            do {
                let dto = try change.document.data(as: WarrantyDTO.self)
                guard let warranty = dto.asWarranty else { return }
                // LWW guard — skip when the local copy is fresher.
                if let localUpdated = localUpdatedAt(warrantyId: warranty.id, in: context),
                   localUpdated > dto.updatedAt {
                    return
                }
                WarrantyEntity.upsert(from: warranty, in: context)
                try context.save()
            } catch {
                lastError = "Decode warranty failed: \(error.localizedDescription)"
            }
        case .removed:
            guard let uuid = UUID(uuidString: change.document.documentID) else { return }
            let request = WarrantyEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            if let entity = try? context.fetch(request).first {
                context.delete(entity)
                try? context.save()
            }
        }
    }

    private func applyClaimChange(_ change: DocumentChange) {
        guard let context else { return }
        switch change.type {
        case .added, .modified:
            do {
                let dto = try change.document.data(as: ClaimDTO.self)
                guard let claim = dto.asClaim else { return }
                ClaimEntity.upsert(from: claim, in: context)
                try context.save()
            } catch {
                lastError = "Decode claim failed: \(error.localizedDescription)"
            }
        case .removed:
            guard let uuid = UUID(uuidString: change.document.documentID) else { return }
            let request = ClaimEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            if let entity = try? context.fetch(request).first {
                context.delete(entity)
                try? context.save()
            }
        }
    }

    // MARK: - Helpers

    private func warrantyCollection() -> CollectionReference? {
        guard let uid else { return nil }
        return Firestore.firestore()
            .collection("users").document(uid)
            .collection("warranties")
    }

    private func claimCollection() -> CollectionReference? {
        guard let uid else { return nil }
        return Firestore.firestore()
            .collection("users").document(uid)
            .collection("claims")
    }

    private func localUpdatedAt(warrantyId: UUID, in context: NSManagedObjectContext) -> Date? {
        let request = WarrantyEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", warrantyId as CVarArg)
        return (try? context.fetch(request).first)?.updatedAt
    }
}

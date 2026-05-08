import Foundation
import CoreData

/// Owns the Core Data stack for WarrantyVault.
/// Single shared instance for the running app, plus an in-memory variant for previews/tests.
final class PersistenceController {

    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true, seedPreviewData: true)

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    private static let seedFlagKey = "hasSeededInitialData"

    init(inMemory: Bool = false, seedPreviewData: Bool = false) {
        container = NSPersistentContainer(name: "WarrantyVault")

        if inMemory, let description = container.persistentStoreDescriptions.first {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unable to load persistent store: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        if inMemory {
            if seedPreviewData { seedFromMockData(force: true) }
        } else {
            seedIfNeeded()
        }
    }

    // MARK: - Seeding

    private func seedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.seedFlagKey) else { return }
        seedFromMockData(force: false)
        defaults.set(true, forKey: Self.seedFlagKey)
    }

    private func seedFromMockData(force: Bool) {
        let context = viewContext

        for w in MockData.warranties {
            _ = WarrantyEntity.upsert(from: w, in: context)
        }
        for c in MockData.claims {
            _ = ClaimEntity.upsert(from: c, in: context)
        }
        for a in MockData.activity {
            _ = ActivityEntity.upsert(from: a, in: context)
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed Core Data: \(error)")
        }
    }
}

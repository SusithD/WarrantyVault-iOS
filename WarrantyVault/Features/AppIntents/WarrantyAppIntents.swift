import AppIntents
import CoreData
import Foundation

/// Voice-activated query: "What warranties are expiring soon in WarrantyVault?"
/// Reads the live Core Data store, filters to active warranties, and reports
/// the next-expiring one along with how many fall in the 30-day "expiring
/// soon" window.
///
/// The intent is auto-discovered by iOS via `WarrantyVaultAppShortcuts` and
/// surfaces in Spotlight, the Shortcuts app, and Siri.
struct ExpiringWarrantiesIntent: AppIntent {
    static var title: LocalizedStringResource = "Expiring Warranties"
    static var description = IntentDescription(
        "Find out which warranties are expiring soon and when the next one ends."
    )

    /// `false` so Siri can answer hands-free — fetching warranties is read-only.
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let warranties = await Self.fetchWarranties()

        let nextActive = warranties
            .filter { $0.status != .expired }
            .min(by: { $0.expiryDate < $1.expiryDate })

        let expiringSoon = warranties.filter { $0.status == .expiringSoon }

        let dialog: IntentDialog
        if let next = nextActive {
            let dateText = next.expiryDate.formatted(date: .abbreviated, time: .omitted)
            if !expiringSoon.isEmpty {
                dialog = IntentDialog(
                    "You have \(expiringSoon.count) warranty\(expiringSoon.count == 1 ? "" : "s") expiring within the next 30 days. The next one is \(next.productName), ending \(dateText)."
                )
            } else {
                dialog = IntentDialog(
                    "Nothing expiring soon. Your next warranty to expire is \(next.productName) on \(dateText)."
                )
            }
        } else {
            dialog = IntentDialog("You don't have any active warranties.")
        }

        return .result(dialog: dialog)
    }

    /// Hop to the main actor to read the view-context safely. App Intents
    /// run in their own task; the Core Data context is bound to the main
    /// queue.
    @MainActor
    private static func fetchWarranties() -> [Warranty] {
        let context = PersistenceController.shared.viewContext
        let request = WarrantyEntity.fetchRequest()
        let entities = (try? context.fetch(request)) ?? []
        return entities.map(Warranty.init)
    }
}

/// Registers the intent with the system so it shows up automatically in the
/// Shortcuts app and is invokable by voice. No user setup required.
struct WarrantyVaultAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ExpiringWarrantiesIntent(),
            phrases: [
                "What's expiring soon in \(.applicationName)",
                "When are my warranties expiring in \(.applicationName)",
                "\(.applicationName) expiring warranties",
                "Check my warranties in \(.applicationName)"
            ],
            shortTitle: "Expiring Warranties",
            systemImageName: "calendar.badge.exclamationmark"
        )
    }
}

import AppIntents
import CoreData
import Foundation


struct ExpiringWarrantiesIntent: AppIntent {
    static var title: LocalizedStringResource = "Expiring Warranties"
    static var description = IntentDescription(
        "Find out which warranties are expiring soon and when the next one ends."
    )


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


    @MainActor
    private static func fetchWarranties() -> [Warranty] {
        let context = PersistenceController.shared.viewContext
        let request = WarrantyEntity.fetchRequest()
        let entities = (try? context.fetch(request)) ?? []
        return entities.map(Warranty.init)
    }
}


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

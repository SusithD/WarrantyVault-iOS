import Foundation

/// Compile-time constants shared between the main app and the widget extension
/// — the App Group identifier, the snapshot filename, and the JSON layout.
enum WidgetSharedConstants {
    /// Must match the App Group capability declared in both `.entitlements` files.
    static let appGroupID = "group.com.warrantyvault.app"
    static let snapshotFilename = "widget_snapshot.json"
}

/// Compact, Codable view of "the next thing the user cares about" — used by
/// the home-screen widget. Written by the main app after every save and read
/// by the widget process. Deliberately small so it crosses the App Group
/// container quickly and doesn't drag Core Data internals into the widget.
struct WidgetSnapshot: Codable, Equatable {
    let nextWarrantyId: UUID?
    let nextProductName: String
    let nextCategoryRaw: String
    let nextDaysUntilExpiry: Int
    let totalActive: Int
    let writtenAt: Date

    static let placeholder = WidgetSnapshot(
        nextWarrantyId: nil,
        nextProductName: "MacBook Pro",
        nextCategoryRaw: "Electronics",
        nextDaysUntilExpiry: 14,
        totalActive: 7,
        writtenAt: Date()
    )

    static let empty = WidgetSnapshot(
        nextWarrantyId: nil,
        nextProductName: "No active warranties",
        nextCategoryRaw: "Other",
        nextDaysUntilExpiry: 0,
        totalActive: 0,
        writtenAt: Date()
    )
}

/// File-backed shared store. Always crosses the App Group container so the
/// widget process can read what the app process wrote.
enum WidgetSnapshotStore {

    /// Snapshot file inside the App Group container. `nil` only if the
    /// container is unavailable (typically because the entitlement is
    /// missing — should not happen in a correctly signed build).
    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSharedConstants.appGroupID)?
            .appendingPathComponent(WidgetSharedConstants.snapshotFilename)
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func read() -> WidgetSnapshot? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}

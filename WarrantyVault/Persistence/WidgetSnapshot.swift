import Foundation


enum WidgetSharedConstants {

    static let appGroupID = "group.com.salwis.warrantyvault"
    static let snapshotFilename = "widget_snapshot.json"
}


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


enum WidgetSnapshotStore {


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

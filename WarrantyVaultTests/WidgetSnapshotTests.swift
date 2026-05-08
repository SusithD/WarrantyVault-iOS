import XCTest
@testable import WarrantyVault

final class WidgetSnapshotTests: XCTestCase {


    func test_codableRoundTrip_preservesAllFields() throws {
        let original = WidgetSnapshot(
            nextWarrantyId: UUID(),
            nextProductName: "MacBook Pro 14\" M3",
            nextCategoryRaw: "Electronics",
            nextDaysUntilExpiry: 23,
            totalActive: 7,
            writtenAt: Date(timeIntervalSince1970: 1_750_000_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetSnapshot.self, from: data)

        XCTAssertEqual(decoded, original)
    }


    func test_placeholder_hasPopulatedFields() {
        let p = WidgetSnapshot.placeholder
        XCTAssertFalse(p.nextProductName.isEmpty)
        XCTAssertFalse(p.nextCategoryRaw.isEmpty)
    }


    func test_empty_codableRoundTripsCleanly() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(WidgetSnapshot.empty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetSnapshot.self, from: data)

        XCTAssertEqual(decoded.totalActive, 0)
        XCTAssertNil(decoded.nextWarrantyId)
    }
}

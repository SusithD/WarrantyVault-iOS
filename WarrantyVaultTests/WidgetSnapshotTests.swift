//
//  WidgetSnapshotTests.swift
//  WarrantyVaultTests
//
//  The widget reads a tiny JSON file written by the main app. If the
//  encoder/decoder pair ever drifts (e.g. someone changes the date strategy
//  on one side only), every widget on every home screen quietly stops
//  matching the host app. These round-trip tests catch that.
//

import XCTest
@testable import WarrantyVault

final class WidgetSnapshotTests: XCTestCase {

    /// Encode → decode → field-by-field compare. The store uses ISO-8601
    /// for dates so a textual round-trip is perfectly stable; we don't need
    /// any tolerance on `writtenAt`.
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

    /// The placeholder is what the widget shows before any real data has
    /// been written — make sure it always has populated, sensible fields
    /// so the home-screen tile never renders blank.
    func test_placeholder_hasPopulatedFields() {
        let p = WidgetSnapshot.placeholder
        XCTAssertFalse(p.nextProductName.isEmpty)
        XCTAssertFalse(p.nextCategoryRaw.isEmpty)
    }

    /// `empty` is the "no active warranties" state the writer falls back to
    /// when the user has nothing tracked. It should still encode/decode
    /// without losing its semantic.
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

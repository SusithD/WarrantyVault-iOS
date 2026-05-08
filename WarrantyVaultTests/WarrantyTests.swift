//
//  WarrantyTests.swift
//  WarrantyVaultTests
//
//  Pure-logic tests for the `Warranty` struct: date arithmetic for
//  `daysRemaining`, `status`, and `coverageProgress`, plus the two derived
//  conveniences (`receiptAttached`, `coordinate`).
//
//  Every test creates the warranty with explicit dates relative to "today"
//  so the assertions are stable across time zones and run dates.
//

import XCTest
@testable import WarrantyVault

final class WarrantyTests: XCTestCase {

    // MARK: - Helpers

    /// `Date` that is `days` away from now (positive = future, negative = past).
    private func date(daysFromNow days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date())!
    }

    /// Builds a minimal `Warranty` with controllable purchase + expiry dates.
    /// Other fields default to empty so the test reads as "this is about dates".
    private func makeWarranty(
        purchase: Date = Date().addingTimeInterval(-86400 * 30),
        expiry: Date,
        receiptImages: [Data] = [],
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> Warranty {
        Warranty(
            productName: "Test product",
            brand: "Test brand",
            category: .electronics,
            purchaseDate: purchase,
            expiryDate: expiry,
            retailer: "Test retailer",
            price: 0,
            receiptImages: receiptImages,
            latitude: latitude,
            longitude: longitude
        )
    }

    // MARK: - daysRemaining

    func test_daysRemaining_futureExpiry_returnsPositive() {
        let w = makeWarranty(expiry: date(daysFromNow: 30))
        // Allow ±1 day of slack because the date math straddles midnight.
        XCTAssertEqual(w.daysRemaining, 30, accuracy: 1)
    }

    func test_daysRemaining_pastExpiry_returnsNegative() {
        let w = makeWarranty(expiry: date(daysFromNow: -10))
        XCTAssertEqual(w.daysRemaining, -10, accuracy: 1)
    }

    func test_daysRemaining_today_returnsZero() {
        let w = makeWarranty(expiry: Date())
        XCTAssertEqual(w.daysRemaining, 0, accuracy: 1)
    }

    // MARK: - status

    func test_status_far_future_isActive() {
        let w = makeWarranty(expiry: date(daysFromNow: 100))
        XCTAssertEqual(w.status, .active)
    }

    func test_status_within_30_days_isExpiringSoon() {
        let w = makeWarranty(expiry: date(daysFromNow: 15))
        XCTAssertEqual(w.status, .expiringSoon)
    }

    func test_status_at_exactly_30_days_isExpiringSoon() {
        // Boundary: the rule is `daysRemaining <= 30 → .expiringSoon`.
        let w = makeWarranty(expiry: date(daysFromNow: 30))
        XCTAssertEqual(w.status, .expiringSoon)
    }

    func test_status_negative_isExpired() {
        let w = makeWarranty(expiry: date(daysFromNow: -1))
        XCTAssertEqual(w.status, .expired)
    }

    // MARK: - coverageProgress

    func test_coverageProgress_halfwayThrough_isApproximatelyHalf() {
        // Purchase 6 months ago, expiry 6 months ahead → ~50% elapsed.
        let w = makeWarranty(
            purchase: date(daysFromNow: -180),
            expiry:   date(daysFromNow: 180)
        )
        XCTAssertEqual(w.coverageProgress, 0.5, accuracy: 0.05)
    }

    func test_coverageProgress_clampsAt1ForExpired() {
        let w = makeWarranty(
            purchase: date(daysFromNow: -400),
            expiry:   date(daysFromNow: -100)
        )
        XCTAssertEqual(w.coverageProgress, 1.0)
    }

    func test_coverageProgress_clampsAt0BeforeStart() {
        // Future purchase date — covers a hypothetical "scheduled" warranty.
        let w = makeWarranty(
            purchase: date(daysFromNow: 30),
            expiry:   date(daysFromNow: 365)
        )
        XCTAssertEqual(w.coverageProgress, 0)
    }

    func test_coverageProgress_zeroSpan_returnsZero() {
        // Purchase == expiry: protect against a divide-by-zero if a user ever
        // saves a malformed warranty.
        let now = Date()
        let w = makeWarranty(purchase: now, expiry: now)
        XCTAssertEqual(w.coverageProgress, 0)
    }

    // MARK: - receiptAttached (derived)

    func test_receiptAttached_isTrueWhenImageDataPresent() {
        let w = makeWarranty(expiry: date(daysFromNow: 30), receiptImages: [Data([0xFF, 0xD8, 0xFF, 0xE0])])
        XCTAssertTrue(w.receiptAttached)
    }

    func test_receiptAttached_isFalseWhenImageDataNil() {
        let w = makeWarranty(expiry: date(daysFromNow: 30), receiptImages: [])
        XCTAssertFalse(w.receiptAttached)
    }

    // MARK: - coordinate (derived)

    func test_coordinate_isNilWhenLatitudeMissing() {
        let w = makeWarranty(expiry: date(daysFromNow: 30), latitude: nil, longitude: -122.0)
        XCTAssertNil(w.coordinate)
    }

    func test_coordinate_isNilWhenLongitudeMissing() {
        let w = makeWarranty(expiry: date(daysFromNow: 30), latitude: 37.3, longitude: nil)
        XCTAssertNil(w.coordinate)
    }

    func test_coordinate_isPresentWhenBothSet() {
        let w = makeWarranty(expiry: date(daysFromNow: 30), latitude: 37.3349, longitude: -122.0090)
        XCTAssertNotNil(w.coordinate)
        XCTAssertEqual(w.coordinate!.latitude, 37.3349, accuracy: 0.0001)
        XCTAssertEqual(w.coordinate!.longitude, -122.0090, accuracy: 0.0001)
    }
}

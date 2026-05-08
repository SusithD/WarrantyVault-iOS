//
//  ReceiptScannerTests.swift
//  WarrantyVaultTests
//
//  Drives the heuristic parsers in `ReceiptScanner` directly via the
//  `parse(text:)` test seam. We don't test the OCR step itself — that's
//  Apple's Vision framework and would require image fixtures. We test
//  what we wrote: the four parsers (retailer / total / date / product).
//

import XCTest
@testable import WarrantyVault

final class ReceiptScannerTests: XCTestCase {

    private let scanner = ReceiptScanner.shared

    // MARK: - Retailer extraction

    func test_retailer_picksFirstAllCapsLineFromHeader() {
        let result = scanner.parse(text: """
        WAL-MART
        Save money. Live better.
        Order #12345
        TOTAL: $12.99
        """)
        XCTAssertEqual(result.retailer, "WAL-MART")
    }

    func test_retailer_skipsBoilerplate() {
        // "RECEIPT" is in the blocklist so it should NOT be picked.
        let result = scanner.parse(text: """
        RECEIPT
        BEST BUY
        Customer copy
        """)
        XCTAssertEqual(result.retailer, "BEST BUY")
    }

    func test_retailer_returnsNilForGarbage() {
        // Numbers / symbols only — no candidate line should match.
        let result = scanner.parse(text: "12345\n***\n$$$")
        XCTAssertNil(result.retailer)
    }

    // MARK: - Total price extraction

    func test_total_extractsLabelledTotal() {
        let result = scanner.parse(text: """
        BEST BUY
        Item A    19.99
        TOTAL: $123.45
        """)
        XCTAssertEqual(result.totalPrice, 123.45)
    }

    func test_total_extractsAmountDue() {
        let result = scanner.parse(text: """
        STORE
        Subtotal 50.00
        Amount Due: 99.99
        """)
        XCTAssertEqual(result.totalPrice, 99.99)
    }

    func test_total_skipsSubtotal() {
        // First-pass parser scans for "total" but excludes "subtotal".
        // Without a labelled total, it should fall back to the largest
        // currency-like number on the receipt.
        let result = scanner.parse(text: """
        STORE
        Subtotal 50.00
        Tax 4.25
        """)
        // Largest = 50.00 (the subtotal value, picked by fallback).
        XCTAssertEqual(result.totalPrice, 50.00)
    }

    func test_total_handlesEuropeanDecimalComma() {
        let result = scanner.parse(text: "Total: 199,95")
        XCTAssertEqual(result.totalPrice, 199.95)
    }

    // MARK: - Date extraction

    func test_date_parsesMMddyyyy_recent() {
        // Format the date from today minus a year so it's always inside the
        // 5-year reasonableness window regardless of when the test runs.
        let cal = Calendar(identifier: .gregorian)
        let oneYearAgo = cal.date(byAdding: .year, value: -1, to: Date())!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yyyy"
        let dateString = formatter.string(from: oneYearAgo)

        let result = scanner.parse(text: "Date: \(dateString)\nTotal: $1.00")
        XCTAssertNotNil(result.purchaseDate)
        // Compare on calendar day, not on the second.
        let parsed = cal.startOfDay(for: result.purchaseDate!)
        let expected = cal.startOfDay(for: oneYearAgo)
        XCTAssertEqual(parsed, expected)
    }

    func test_date_rejectsFarFuture() {
        let result = scanner.parse(text: "Issued: 12/25/2099")
        XCTAssertNil(result.purchaseDate)
    }

    func test_date_rejectsTooOld() {
        // 1990 is far older than the 5-year reasonableness window.
        let result = scanner.parse(text: "Date: 03/15/1990")
        XCTAssertNil(result.purchaseDate)
    }

    func test_date_returnsNilWhenAbsent() {
        let result = scanner.parse(text: "BEST BUY\nTotal: $19.99")
        XCTAssertNil(result.purchaseDate)
    }

    // MARK: - Product name extraction

    func test_productName_picksLongestNonHeaderLine() {
        let result = scanner.parse(text: """
        BEST BUY
        Order #12345
        Apple iPhone 15 Pro 256GB Space Black
        Tax 8.50
        TOTAL: $999.99
        """)
        XCTAssertEqual(result.productName, "Apple iPhone 15 Pro 256GB Space Black")
    }

    // MARK: - Empty / nonsense input

    func test_emptyText_returnsAllNilStructuredFields() {
        let result = scanner.parse(text: "")
        XCTAssertNil(result.retailer)
        XCTAssertNil(result.totalPrice)
        XCTAssertNil(result.purchaseDate)
        XCTAssertNil(result.productName)
        XCTAssertEqual(result.rawText, "")
    }

    func test_nonsenseText_returnsAllNilStructuredFields() {
        let result = scanner.parse(text: "@@@\n###\n***")
        XCTAssertNil(result.retailer)
        XCTAssertNil(result.totalPrice)
        XCTAssertNil(result.purchaseDate)
        XCTAssertNil(result.productName)
    }
}

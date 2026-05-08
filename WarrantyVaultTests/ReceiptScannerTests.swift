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

    func test_total_returnsNilWhenOnlySubtotalAndTaxPresent() {
        // Strict behavior: every line on this receipt is in the exclusion
        // list (subtotal, tax). Returning the subtotal as "total" would be
        // misleading data. Better to return nil and let the user fill it
        // manually than confidently misreport the wrong number.
        let result = scanner.parse(text: """
        STORE
        Subtotal 50.00
        Tax 4.25
        """)
        XCTAssertNil(result.totalPrice)
    }

    func test_total_ignoresCashTenderedAndChange() {
        // Common pitfall: "Cash Tendered" is what the customer handed over
        // and is typically *larger* than the actual total, so a naïve
        // "largest number" fallback would pick it. The exclusion list
        // prevents that — the labelled TOTAL wins.
        let result = scanner.parse(text: """
        STORE
        TOTAL: $42.50
        Cash Tendered: 50.00
        Change: 7.50
        """)
        XCTAssertEqual(result.totalPrice, 42.50)
    }

    func test_total_grandTotalBeatsAmount() {
        // Strong-keyword pass should pick "Grand Total" even if "Amount"
        // appears earlier — strong keywords are checked first.
        let result = scanner.parse(text: """
        STORE
        Amount: 100.00
        Grand Total: 108.50
        """)
        XCTAssertEqual(result.totalPrice, 108.50)
    }

    func test_total_rejectsImplausiblyLargeValue() {
        // "1234567.89" (1.2 million) on a receipt is almost certainly an
        // OCR misread of a SKU / barcode / serial. Reject it.
        let result = scanner.parse(text: """
        STORE
        SKU 1234567.89
        Total: $19.99
        """)
        XCTAssertEqual(result.totalPrice, 19.99)
    }

    func test_total_handlesThousandSeparator() {
        let result = scanner.parse(text: "TOTAL: $1,234.56")
        XCTAssertEqual(result.totalPrice, 1234.56)
    }

    func test_total_handlesEuroSymbol() {
        let result = scanner.parse(text: "Grand Total: €299.50")
        XCTAssertEqual(result.totalPrice, 299.50)
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

    // MARK: - Date — written-month formats

    func test_date_parsesWrittenMonthShort() throws {
        // "Jan 15, 2025" — common on US receipts. Skip if the year would
        // fall outside the 10-year reasonableness window for whatever
        // reason; we use a controlled date one year ago.
        let cal = Calendar(identifier: .gregorian)
        let oneYearAgo = cal.date(byAdding: .year, value: -1, to: Date())!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        let dateString = formatter.string(from: oneYearAgo)

        let result = scanner.parse(text: "Date: \(dateString)\nTotal: $1.00")
        let parsed = try XCTUnwrap(result.purchaseDate)
        XCTAssertEqual(cal.startOfDay(for: parsed),
                       cal.startOfDay(for: oneYearAgo))
    }

    func test_date_parsesWrittenMonthLongDayFirst() throws {
        // "15 January 2025" — common on UK / European receipts.
        let cal = Calendar(identifier: .gregorian)
        let oneYearAgo = cal.date(byAdding: .year, value: -1, to: Date())!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMMM yyyy"
        let dateString = formatter.string(from: oneYearAgo)

        let result = scanner.parse(text: "Issued: \(dateString)\nTotal: £1.00")
        let parsed = try XCTUnwrap(result.purchaseDate)
        XCTAssertEqual(cal.startOfDay(for: parsed),
                       cal.startOfDay(for: oneYearAgo))
    }

    // MARK: - Date — keyword scoring

    func test_date_prefersPurchaseDateOverDueDate() throws {
        // Two dates on the same receipt. Naïve parser picks the first one.
        // Smart parser scores by keyword proximity: "Purchased" wins over
        // "Due" — and the right answer is the purchased date.
        let cal = Calendar(identifier: .gregorian)
        let purchased = cal.date(byAdding: .day, value: -10, to: Date())!
        let due = cal.date(byAdding: .day, value: 30, to: Date())!  // future
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yyyy"

        let receipt = """
        STORE
        Due Date: \(formatter.string(from: due))
        Purchased: \(formatter.string(from: purchased))
        Total: $19.99
        """
        let result = scanner.parse(text: receipt)
        let parsed = try XCTUnwrap(result.purchaseDate)
        XCTAssertEqual(cal.startOfDay(for: parsed),
                       cal.startOfDay(for: purchased))
    }

    // MARK: - Retailer — scoring & rejection

    func test_retailer_skipsPhoneNumber() {
        // Some receipts print the phone number on the very first line.
        // The scorer must reject it — picking "555-867-5309" as the
        // retailer is a known OCR pitfall.
        let result = scanner.parse(text: """
        555-867-5309
        BEST BUY
        123 Main Street
        TOTAL: $1.00
        """)
        XCTAssertEqual(result.retailer, "BEST BUY")
    }

    func test_retailer_skipsAddressLine() {
        // Address lines (number + street word) shouldn't beat the brand,
        // even when they appear first in the recognised lines.
        let result = scanner.parse(text: """
        1234 Main Avenue Suite 100
        APPLE STORE
        Customer copy
        """)
        XCTAssertEqual(result.retailer, "APPLE STORE")
    }

    func test_retailer_titleCasePicksUpBrand() {
        // Some receipts have title-case headers ("Best Buy", "Pottery Barn")
        // rather than ALL CAPS. The scorer should still find them.
        let result = scanner.parse(text: """
        Pottery Barn
        Customer Service: 800-555-1234
        """)
        XCTAssertEqual(result.retailer, "Pottery Barn")
    }

    func test_retailer_skipsTaglines() {
        // "SAVE MONEY. LIVE BETTER." is Walmart's tagline — it's all-caps
        // and short, so a naïve scorer would pick it before the actual
        // retailer line. The tagline-words penalty handles this.
        let result = scanner.parse(text: """
        SAVE MONEY. LIVE BETTER.
        WAL-MART
        TOTAL: $1.00
        """)
        XCTAssertEqual(result.retailer, "WAL-MART")
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

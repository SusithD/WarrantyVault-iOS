import XCTest
@testable import WarrantyVault

final class ReceiptScannerTests: XCTestCase {

    private let scanner = ReceiptScanner.shared


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

        let result = scanner.parse(text: """
        RECEIPT
        BEST BUY
        Customer copy
        """)
        XCTAssertEqual(result.retailer, "BEST BUY")
    }

    func test_retailer_returnsNilForGarbage() {

        let result = scanner.parse(text: "12345\n***\n$$$")
        XCTAssertNil(result.retailer)
    }


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


        let result = scanner.parse(text: """
        STORE
        Subtotal 50.00
        Tax 4.25
        """)
        XCTAssertNil(result.totalPrice)
    }

    func test_total_ignoresCashTenderedAndChange() {


        let result = scanner.parse(text: """
        STORE
        TOTAL: $42.50
        Cash Tendered: 50.00
        Change: 7.50
        """)
        XCTAssertEqual(result.totalPrice, 42.50)
    }

    func test_total_grandTotalBeatsAmount() {


        let result = scanner.parse(text: """
        STORE
        Amount: 100.00
        Grand Total: 108.50
        """)
        XCTAssertEqual(result.totalPrice, 108.50)
    }

    func test_total_rejectsImplausiblyLargeValue() {


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


    func test_date_parsesMMddyyyy_recent() {


        let cal = Calendar(identifier: .gregorian)
        let oneYearAgo = cal.date(byAdding: .year, value: -1, to: Date())!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yyyy"
        let dateString = formatter.string(from: oneYearAgo)

        let result = scanner.parse(text: "Date: \(dateString)\nTotal: $1.00")
        XCTAssertNotNil(result.purchaseDate)

        let parsed = cal.startOfDay(for: result.purchaseDate!)
        let expected = cal.startOfDay(for: oneYearAgo)
        XCTAssertEqual(parsed, expected)
    }

    func test_date_rejectsFarFuture() {
        let result = scanner.parse(text: "Issued: 12/25/2099")
        XCTAssertNil(result.purchaseDate)
    }

    func test_date_rejectsTooOld() {

        let result = scanner.parse(text: "Date: 03/15/1990")
        XCTAssertNil(result.purchaseDate)
    }

    func test_date_returnsNilWhenAbsent() {
        let result = scanner.parse(text: "BEST BUY\nTotal: $19.99")
        XCTAssertNil(result.purchaseDate)
    }


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


    func test_date_parsesWrittenMonthShort() throws {


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


    func test_date_prefersPurchaseDateOverDueDate() throws {


        let cal = Calendar(identifier: .gregorian)
        let purchased = cal.date(byAdding: .day, value: -10, to: Date())!
        let due = cal.date(byAdding: .day, value: 30, to: Date())!
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


    func test_retailer_skipsPhoneNumber() {


        let result = scanner.parse(text: """
        555-867-5309
        BEST BUY
        123 Main Street
        TOTAL: $1.00
        """)
        XCTAssertEqual(result.retailer, "BEST BUY")
    }

    func test_retailer_skipsAddressLine() {


        let result = scanner.parse(text: """
        1234 Main Avenue Suite 100
        APPLE STORE
        Customer copy
        """)
        XCTAssertEqual(result.retailer, "APPLE STORE")
    }

    func test_retailer_titleCasePicksUpBrand() {


        let result = scanner.parse(text: """
        Pottery Barn
        Customer Service: 800-555-1234
        """)
        XCTAssertEqual(result.retailer, "Pottery Barn")
    }

    func test_retailer_skipsTaglines() {


        let result = scanner.parse(text: """
        SAVE MONEY. LIVE BETTER.
        WAL-MART
        TOTAL: $1.00
        """)
        XCTAssertEqual(result.retailer, "WAL-MART")
    }


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

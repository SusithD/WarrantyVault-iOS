import XCTest
@testable import WarrantyVault

final class AppStoreTests: XCTestCase {


    private func warranty(
        product: String,
        brand: String = "BrandX",
        retailer: String = "RetailerX",
        category: WarrantyCategory = .electronics,
        expiresInDays: Int = 100
    ) -> Warranty {
        Warranty(
            productName: product,
            brand: brand,
            category: category,
            purchaseDate: Date().addingTimeInterval(-86400 * 30),
            expiryDate: Date().addingTimeInterval(86400 * Double(expiresInDays)),
            retailer: retailer,
            price: 0
        )
    }


    private func makeStore(warranties: [Warranty] = [], claims: [Claim] = []) -> AppStore {
        AppStore(
            warranties: warranties,
            claims: claims,
            household: MockData.household,
            activity: [],
            messages: []
        )
    }


    func test_filteredWarranties_returnsAll_whenSearchEmpty() {
        let store = makeStore(warranties: [
            warranty(product: "iPhone"),
            warranty(product: "MacBook")
        ])
        XCTAssertEqual(store.filteredWarranties.count, 2)
    }

    func test_filteredWarranties_filtersByProductName() {
        let store = makeStore(warranties: [
            warranty(product: "iPhone 15 Pro"),
            warranty(product: "MacBook Pro"),
            warranty(product: "AirPods")
        ])
        store.searchText = "phone"
        let names = store.filteredWarranties.map(\.productName)
        XCTAssertEqual(names, ["iPhone 15 Pro"])
    }

    func test_filteredWarranties_filtersByBrand() {
        let store = makeStore(warranties: [
            warranty(product: "TV",     brand: "Samsung"),
            warranty(product: "Laptop", brand: "Apple")
        ])
        store.searchText = "apple"
        XCTAssertEqual(store.filteredWarranties.map(\.brand), ["Apple"])
    }

    func test_filteredWarranties_filtersByRetailer() {
        let store = makeStore(warranties: [
            warranty(product: "TV",     retailer: "Best Buy"),
            warranty(product: "Laptop", retailer: "Apple Store")
        ])
        store.searchText = "best"
        XCTAssertEqual(store.filteredWarranties.map(\.retailer), ["Best Buy"])
    }


    func test_filteredWarranties_filtersByCategory() {
        let store = makeStore(warranties: [
            warranty(product: "iPhone",   category: .electronics),
            warranty(product: "Washer",   category: .appliance),
            warranty(product: "Tesla",    category: .vehicle)
        ])
        store.categoryFilter = .appliance
        XCTAssertEqual(store.filteredWarranties.map(\.productName), ["Washer"])
    }


    func test_filteredWarranties_sortedByExpiryAscending() {
        let store = makeStore(warranties: [
            warranty(product: "Late",   expiresInDays: 300),
            warranty(product: "Early",  expiresInDays: 30),
            warranty(product: "Middle", expiresInDays: 100)
        ])
        XCTAssertEqual(
            store.filteredWarranties.map(\.productName),
            ["Early", "Middle", "Late"]
        )
    }


    func test_activeCount_includesOnlyActiveWarranties() {
        let store = makeStore(warranties: [
            warranty(product: "Active1",       expiresInDays: 100),
            warranty(product: "Active2",       expiresInDays: 200),
            warranty(product: "ExpiringSoon",  expiresInDays: 10),
            warranty(product: "Expired",       expiresInDays: -5)
        ])
        XCTAssertEqual(store.activeCount, 2)
    }

    func test_expiringSoonCount_matchesItemsWithin30Days() {
        let store = makeStore(warranties: [
            warranty(product: "Soon1", expiresInDays: 5),
            warranty(product: "Soon2", expiresInDays: 25),
            warranty(product: "Active", expiresInDays: 100)
        ])
        XCTAssertEqual(store.expiringSoonCount, 2)
    }

    func test_expiredCount_includesOnlyExpired() {
        let store = makeStore(warranties: [
            warranty(product: "Expired", expiresInDays: -1),
            warranty(product: "Active",  expiresInDays: 100)
        ])
        XCTAssertEqual(store.expiredCount, 1)
    }


    func test_openClaimsCount_excludesCompletedAndRejected() {
        let warrantyId = UUID()
        let claims = [
            Claim(referenceCode: "#1", warrantyID: warrantyId, productName: "X",
                  issueSummary: "y", status: .submitted,    filedDate: Date(), updatedDate: Date(), timeline: []),
            Claim(referenceCode: "#2", warrantyID: warrantyId, productName: "X",
                  issueSummary: "y", status: .underReview,  filedDate: Date(), updatedDate: Date(), timeline: []),
            Claim(referenceCode: "#3", warrantyID: warrantyId, productName: "X",
                  issueSummary: "y", status: .completed,    filedDate: Date(), updatedDate: Date(), timeline: []),
            Claim(referenceCode: "#4", warrantyID: warrantyId, productName: "X",
                  issueSummary: "y", status: .rejected,     filedDate: Date(), updatedDate: Date(), timeline: [])
        ]
        let store = makeStore(claims: claims)

        XCTAssertEqual(store.openClaimsCount, 2)
    }
}

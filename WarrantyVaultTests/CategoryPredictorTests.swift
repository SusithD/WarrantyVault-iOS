import XCTest
import NaturalLanguage
@testable import WarrantyVault

final class CategoryPredictorTests: XCTestCase {

    private let predictor = CategoryPredictor.shared


    func test_brand_appleIsElectronics() {
        XCTAssertEqual(predictor.predict(from: "Apple iPhone 15 Pro 256GB"), .electronics)
    }

    func test_brand_dewaltIsTools() {
        XCTAssertEqual(predictor.predict(from: "DeWalt 20V impact driver kit"), .tools)
    }

    func test_brand_teslaIsVehicle() {
        XCTAssertEqual(predictor.predict(from: "Tesla Model Y Long Range"), .vehicle)
    }

    func test_brand_tiffanyIsJewelry() {
        XCTAssertEqual(predictor.predict(from: "Tiffany & Co Soleste platinum ring"), .jewelry)
    }

    func test_brand_hermanMillerIsFurniture() {
        XCTAssertEqual(predictor.predict(from: "Herman Miller Aeron chair"), .furniture)
    }


    func test_brand_longestMatchWins_lgWashtower() {
        XCTAssertEqual(predictor.predict(from: "LG WashTower 27 inch front load"), .appliance)
    }

    func test_brand_longestMatchWins_lgOled() {
        XCTAssertEqual(predictor.predict(from: "LG OLED C3 65 inch"), .electronics)
    }


    func test_embeddingFallback_unseenTelevisionBrandIsElectronics() throws {
        try XCTSkipUnless(NLEmbedding.wordEmbedding(for: .english) != nil,
                          "English NLEmbedding model not available on this runtime")


        XCTAssertEqual(predictor.predict(from: "Vizio M-Series 65 inch 4K television"), .electronics)
    }

    func test_embeddingFallback_unseenFreezerBrandIsAppliance() throws {
        try XCTSkipUnless(NLEmbedding.wordEmbedding(for: .english) != nil,
                          "English NLEmbedding model not available on this runtime")
        XCTAssertEqual(predictor.predict(from: "Frigidaire upright freezer 16 cu ft"), .appliance)
    }

    func test_embeddingFallback_genericNounsResolveToCategory() throws {
        try XCTSkipUnless(NLEmbedding.wordEmbedding(for: .english) != nil,
                          "English NLEmbedding model not available on this runtime")

        XCTAssertEqual(predictor.predict(from: "Generic gold ring with diamond accents"), .jewelry)
    }


    func test_returnsNilForCompleteNonsense() {


        XCTAssertNil(predictor.predict(from: "xqzplmw vqfffr ljkznm"))
    }

    func test_returnsNilForEmptyInput() {
        XCTAssertNil(predictor.predict(from: ""))
    }

    func test_returnsNilForWhitespaceOnly() {
        XCTAssertNil(predictor.predict(from: "   \n  "))
    }
}

//
//  CategoryPredictorTests.swift
//  WarrantyVaultTests
//
//  Two layers under test:
//    1. The brand/token dictionary — exact substring matches that should
//       resolve quickly and deterministically.
//    2. The NLEmbedding fallback — for unseen brands, the predictor should
//       still resolve via word-similarity to the category anchors.
//
//  The fallback path requires the iOS English embedding model. It ships with
//  the simulator, but if it ever isn't present (e.g. on a stripped CI image),
//  those tests are skipped via `XCTSkip`.
//

import XCTest
import NaturalLanguage
@testable import WarrantyVault

final class CategoryPredictorTests: XCTestCase {

    private let predictor = CategoryPredictor.shared

    // MARK: - Brand dictionary

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

    /// Multi-word tokens must beat single-word prefixes. "lg washtower" is
    /// .appliance, while "lg oled" is .electronics — without the longest-
    /// match-wins rule, both would resolve to whichever "lg*" token appears
    /// first in the dictionary.
    func test_brand_longestMatchWins_lgWashtower() {
        XCTAssertEqual(predictor.predict(from: "LG WashTower 27 inch front load"), .appliance)
    }

    func test_brand_longestMatchWins_lgOled() {
        XCTAssertEqual(predictor.predict(from: "LG OLED C3 65 inch"), .electronics)
    }

    // MARK: - Embedding fallback (unseen brands)

    func test_embeddingFallback_unseenTelevisionBrandIsElectronics() throws {
        try XCTSkipUnless(NLEmbedding.wordEmbedding(for: .english) != nil,
                          "English NLEmbedding model not available on this runtime")
        // "Vizio" is not in the brand dictionary, but "television" is an
        // anchor for `.electronics` so cosine distance should resolve it.
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
        // No brand at all — should still resolve via the embedding pass.
        XCTAssertEqual(predictor.predict(from: "Generic gold ring with diamond accents"), .jewelry)
    }

    // MARK: - No-match path

    func test_returnsNilForCompleteNonsense() {
        // Random characters → nothing in the brand dict, embedding distance
        // far above the threshold → predictor returns nil.
        XCTAssertNil(predictor.predict(from: "xqzplmw vqfffr ljkznm"))
    }

    func test_returnsNilForEmptyInput() {
        XCTAssertNil(predictor.predict(from: ""))
    }

    func test_returnsNilForWhitespaceOnly() {
        XCTAssertNil(predictor.predict(from: "   \n  "))
    }
}

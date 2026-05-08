//
//  PersistenceBridgingTests.swift
//  WarrantyVaultTests
//
//  Validates that struct ↔ entity bridging is loss-less for the three
//  persisted entities (Warranty, Claim, Activity). Each test creates a
//  fresh in-memory Core Data context per test so seed state can't leak.
//
//  The pattern for each round-trip is:
//      1. Build a struct
//      2. Upsert into the context
//      3. Save
//      4. Fetch the entity back by `id`
//      5. Bridge the entity back into a struct
//      6. Assert structural equality on every field that survives storage
//

import XCTest
import CoreData
@testable import WarrantyVault

final class PersistenceBridgingTests: XCTestCase {

    private var controller: PersistenceController!
    private var ctx: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        // `inMemory: true` routes the store to /dev/null. Each test gets a
        // brand-new controller, so prior tests can't influence the next.
        controller = PersistenceController(inMemory: true, seedPreviewData: false)
        ctx = controller.viewContext
    }

    override func tearDown() {
        ctx = nil
        controller = nil
        super.tearDown()
    }

    // MARK: - Warranty

    func test_warranty_roundTrip_preservesAllFields() throws {
        let original = Warranty(
            productName: "MacBook Pro 14\" M3",
            brand: "Apple",
            category: .electronics,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            expiryDate: Date(timeIntervalSince1970: 1_800_000_000),
            retailer: "Apple Store",
            price: 2399.99,
            serialNumber: "C02ZL0AC-JK23",
            notes: "AppleCare+ included.",
            receiptImage: Data([0xFF, 0xD8, 0xFF, 0xE0]),  // 4-byte JPEG-prefix as a stand-in
            reminderEnabled: true,
            latitude: 37.3349,
            longitude: -122.0090,
            eventIdentifier: "EVT-12345"
        )

        WarrantyEntity.upsert(from: original, in: ctx)
        try ctx.save()

        let fetched = try fetchWarranty(id: original.id)
        let roundTripped = Warranty(fetched)

        XCTAssertEqual(roundTripped.id, original.id)
        XCTAssertEqual(roundTripped.productName, original.productName)
        XCTAssertEqual(roundTripped.brand, original.brand)
        XCTAssertEqual(roundTripped.category, original.category)
        XCTAssertEqual(roundTripped.purchaseDate, original.purchaseDate)
        XCTAssertEqual(roundTripped.expiryDate, original.expiryDate)
        XCTAssertEqual(roundTripped.retailer, original.retailer)
        XCTAssertEqual(roundTripped.price, original.price)
        XCTAssertEqual(roundTripped.serialNumber, original.serialNumber)
        XCTAssertEqual(roundTripped.notes, original.notes)
        XCTAssertEqual(roundTripped.receiptImage, original.receiptImage)
        XCTAssertEqual(roundTripped.reminderEnabled, original.reminderEnabled)
        XCTAssertEqual(roundTripped.latitude, original.latitude)
        XCTAssertEqual(roundTripped.longitude, original.longitude)
        XCTAssertEqual(roundTripped.eventIdentifier, original.eventIdentifier)
    }

    func test_warranty_upsert_replacesExistingRow() throws {
        let id = UUID()
        let v1 = Warranty(
            id: id, productName: "Original", brand: "B", category: .other,
            purchaseDate: Date(), expiryDate: Date().addingTimeInterval(86400),
            retailer: "R", price: 10
        )
        WarrantyEntity.upsert(from: v1, in: ctx)
        try ctx.save()

        // Same `id`, different content — upsert should mutate in place.
        var v2 = v1
        v2.productName = "Updated"
        v2.price = 99
        WarrantyEntity.upsert(from: v2, in: ctx)
        try ctx.save()

        // There should still be exactly one row with this id.
        let request = WarrantyEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let rows = try ctx.fetch(request)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.productName, "Updated")
        XCTAssertEqual(rows.first?.price, 99)
    }

    // MARK: - Claim (with timeline JSON)

    func test_claim_roundTrip_preservesTimelineJSON() throws {
        let timeline = [
            ClaimTimelineEvent(title: "Submitted",  subtitle: "Form received",   date: Date(timeIntervalSince1970: 1_700_000_000), isDone: true),
            ClaimTimelineEvent(title: "Reviewing",  subtitle: "Tech assigned",   date: Date(timeIntervalSince1970: 1_700_100_000), isDone: false)
        ]
        let original = Claim(
            referenceCode: "#CLM-2026-0412",
            warrantyID: UUID(),
            productName: "LG WashTower",
            issueSummary: "Drum vibration on spin cycle",
            status: .underReview,
            filedDate: Date(timeIntervalSince1970: 1_700_000_000),
            updatedDate: Date(timeIntervalSince1970: 1_700_100_000),
            timeline: timeline
        )

        ClaimEntity.upsert(from: original, in: ctx)
        try ctx.save()

        let fetched = try fetchClaim(id: original.id)
        let roundTripped = Claim(fetched)

        XCTAssertEqual(roundTripped.referenceCode, original.referenceCode)
        XCTAssertEqual(roundTripped.warrantyID,    original.warrantyID)
        XCTAssertEqual(roundTripped.productName,   original.productName)
        XCTAssertEqual(roundTripped.issueSummary,  original.issueSummary)
        XCTAssertEqual(roundTripped.status,        original.status)
        XCTAssertEqual(roundTripped.filedDate,     original.filedDate)
        XCTAssertEqual(roundTripped.updatedDate,   original.updatedDate)
        // Timeline survives via JSON-encoded blob on the entity.
        XCTAssertEqual(roundTripped.timeline.count, 2)
        XCTAssertEqual(roundTripped.timeline.first?.title, "Submitted")
        XCTAssertEqual(roundTripped.timeline.last?.isDone, false)
    }

    // MARK: - ActivityEntry

    func test_activityEntry_roundTrip() throws {
        let original = ActivityEntry(
            kind: .added,
            actorName: "Jamie Chen",
            actorInitials: "JC",
            actorAccentHex: "#0A84FF",
            title: "Added MacBook Pro",
            detail: "Electronics · Apple",
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        ActivityEntity.upsert(from: original, in: ctx)
        try ctx.save()

        let request = ActivityEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", original.id as CVarArg)
        let entity = try XCTUnwrap(ctx.fetch(request).first)
        let roundTripped = ActivityEntry(entity)

        XCTAssertEqual(roundTripped.id, original.id)
        XCTAssertEqual(roundTripped.kind, original.kind)
        XCTAssertEqual(roundTripped.actorName, original.actorName)
        XCTAssertEqual(roundTripped.actorInitials, original.actorInitials)
        XCTAssertEqual(roundTripped.actorAccentHex, original.actorAccentHex)
        XCTAssertEqual(roundTripped.title, original.title)
        XCTAssertEqual(roundTripped.detail, original.detail)
        XCTAssertEqual(roundTripped.occurredAt, original.occurredAt)
    }

    // MARK: - Helpers

    private func fetchWarranty(id: UUID) throws -> WarrantyEntity {
        let request = WarrantyEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try XCTUnwrap(ctx.fetch(request).first, "WarrantyEntity not found for id \(id)")
    }

    private func fetchClaim(id: UUID) throws -> ClaimEntity {
        let request = ClaimEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try XCTUnwrap(ctx.fetch(request).first, "ClaimEntity not found for id \(id)")
    }
}

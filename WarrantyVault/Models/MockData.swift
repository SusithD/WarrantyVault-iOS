import Foundation

/// Static sample data used to populate screens in previews and the first build of the app.
/// Swap this file out for real persistence / networking later.
enum MockData {

    // MARK: Helpers

    private static let calendar = Calendar(identifier: .gregorian)

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps) ?? Date()
    }

    private static func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    private static func daysAhead(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }

    // MARK: Warranties

    static let warranties: [Warranty] = [
        Warranty(
            productName: "Samsung QN90C 65\" Neo QLED",
            brand: "Samsung",
            category: .electronics,
            purchaseDate: date(2025, 2, 12),
            expiryDate: daysAhead(312),
            retailer: "Best Buy",
            price: 1999.00,
            serialNumber: "SM-QN90C-8827-33021",
            notes: "Includes 2 year manufacturer + 1 year store extended."
        ),
        Warranty(
            productName: "MacBook Pro 14\" M3",
            brand: "Apple",
            category: .electronics,
            purchaseDate: date(2025, 11, 4),
            expiryDate: daysAhead(214),
            retailer: "Apple Store",
            price: 2399.00,
            serialNumber: "C02ZL0AC-JK23",
            notes: "AppleCare+ included."
        ),
        Warranty(
            productName: "LG WashTower",
            brand: "LG",
            category: .appliance,
            purchaseDate: date(2024, 7, 18),
            expiryDate: daysAhead(24),
            retailer: "Home Depot",
            price: 2699.00,
            serialNumber: "WT-7901-XL",
            notes: "Front-load, extended coverage."
        ),
        Warranty(
            productName: "Dyson V15 Detect",
            brand: "Dyson",
            category: .appliance,
            purchaseDate: date(2024, 1, 9),
            expiryDate: daysAhead(-12),
            retailer: "Dyson.com",
            price: 749.00,
            serialNumber: "V15-DET-2001",
            notes: "Expired — renew soon."
        ),
        Warranty(
            productName: "Herman Miller Aeron",
            brand: "Herman Miller",
            category: .furniture,
            purchaseDate: date(2023, 5, 2),
            expiryDate: daysAhead(980),
            retailer: "HermanMiller.com",
            price: 1695.00,
            serialNumber: "HM-AER-SIZEB",
            notes: "12-year warranty."
        ),
        Warranty(
            productName: "Tesla Model Y",
            brand: "Tesla",
            category: .vehicle,
            purchaseDate: date(2024, 9, 1),
            expiryDate: daysAhead(740),
            retailer: "Tesla",
            price: 48900.00,
            serialNumber: "5YJYG...",
            notes: "Basic + battery/drive unit coverage."
        ),
        Warranty(
            productName: "Bosch 18V Cordless Drill",
            brand: "Bosch",
            category: .tools,
            purchaseDate: date(2025, 6, 10),
            expiryDate: daysAhead(420),
            retailer: "Lowe's",
            price: 189.00,
            serialNumber: "BOS-18V-441",
            notes: "3-year pro tool warranty."
        )
    ]

    // MARK: Claims

    static let claims: [Claim] = [
        Claim(
            referenceCode: "#CLM-2026-0412",
            warrantyID: warranties[2].id,
            productName: "LG WashTower",
            issueSummary: "Intermittent drum vibration during spin cycle.",
            status: .underReview,
            filedDate: daysAgo(4),
            updatedDate: daysAgo(1),
            timeline: [
                ClaimTimelineEvent(title: "Claim submitted",   subtitle: "Form and evidence received",  date: daysAgo(4), isDone: true),
                ClaimTimelineEvent(title: "Documents verified", subtitle: "Receipt and serial confirmed", date: daysAgo(3), isDone: true),
                ClaimTimelineEvent(title: "Under review",      subtitle: "Technician assigned",          date: daysAgo(1), isDone: true),
                ClaimTimelineEvent(title: "Repair or replace", subtitle: "Pending decision",             date: daysAhead(2), isDone: false),
                ClaimTimelineEvent(title: "Completed",         subtitle: "Claim closed",                 date: daysAhead(6), isDone: false)
            ]
        ),
        Claim(
            referenceCode: "#CLM-2026-0318",
            warrantyID: warranties[1].id,
            productName: "MacBook Pro 14\" M3",
            issueSummary: "Trackpad click inconsistency.",
            status: .approved,
            filedDate: daysAgo(20),
            updatedDate: daysAgo(2),
            timeline: [
                ClaimTimelineEvent(title: "Claim submitted",   subtitle: "Form received",                date: daysAgo(20), isDone: true),
                ClaimTimelineEvent(title: "Documents verified", subtitle: "Proof of purchase confirmed", date: daysAgo(18), isDone: true),
                ClaimTimelineEvent(title: "Under review",      subtitle: "Apple diagnostics complete",   date: daysAgo(10), isDone: true),
                ClaimTimelineEvent(title: "Approved",          subtitle: "Repair approved",              date: daysAgo(2),  isDone: true),
                ClaimTimelineEvent(title: "Completed",         subtitle: "Awaiting drop-off",            date: daysAhead(3), isDone: false)
            ]
        ),
        Claim(
            referenceCode: "#CLM-2026-0201",
            warrantyID: warranties[3].id,
            productName: "Dyson V15 Detect",
            issueSummary: "Battery no longer holds a charge.",
            status: .completed,
            filedDate: daysAgo(60),
            updatedDate: daysAgo(35),
            timeline: [
                ClaimTimelineEvent(title: "Claim submitted",   subtitle: "Form received",       date: daysAgo(60), isDone: true),
                ClaimTimelineEvent(title: "Documents verified", subtitle: "Receipt on file",    date: daysAgo(58), isDone: true),
                ClaimTimelineEvent(title: "Under review",      subtitle: "Battery test passed", date: daysAgo(50), isDone: true),
                ClaimTimelineEvent(title: "Approved",          subtitle: "Replacement issued",  date: daysAgo(45), isDone: true),
                ClaimTimelineEvent(title: "Completed",         subtitle: "Delivered to home",   date: daysAgo(35), isDone: true)
            ]
        )
    ]

    // MARK: Chat

    static let chatMessages: [ChatMessage] = [
        ChatMessage(text: "Hi Jamie — thanks for filing #CLM-2026-0412. I've pulled up your LG WashTower claim.", isFromUser: false, sentAt: daysAgo(1), agentName: "Sofia"),
        ChatMessage(text: "Hi Sofia — the drum vibration seems to happen only when the washer is more than half full.", isFromUser: true, sentAt: daysAgo(1)),
        ChatMessage(text: "Got it. Can you upload a short video of the vibration and share the load weight?", isFromUser: false, sentAt: daysAgo(1), agentName: "Sofia"),
        ChatMessage(text: "Sure, sending a 20-second clip now.", isFromUser: true, sentAt: daysAgo(1)),
        ChatMessage(text: "Perfect — received. A technician will reach out in 24 hours to book a visit.", isFromUser: false, sentAt: Date().addingTimeInterval(-3600), agentName: "Sofia")
    ]

    // MARK: Household

    static let household: Household = {
        let members: [HouseholdMember] = [
            HouseholdMember(name: "Jamie Chen",   email: "jamie@chenfamily.co",    role: .owner,  avatarInitials: "JC", accentHex: "#0A84FF", joinedDate: daysAgo(420), itemCount: 14),
            HouseholdMember(name: "Morgan Chen",  email: "morgan@chenfamily.co",   role: .admin,  avatarInitials: "MC", accentHex: "#FFC4A3", joinedDate: daysAgo(380), itemCount: 7),
            HouseholdMember(name: "Alex Park",    email: "alex.park@outlook.com",  role: .member, avatarInitials: "AP", accentHex: "#C7E6C4", joinedDate: daysAgo(210), itemCount: 3),
            HouseholdMember(name: "Riley Chen",   email: "riley@chenfamily.co",    role: .viewer, avatarInitials: "RC", accentHex: "#E2CBEF", joinedDate: daysAgo(90),  itemCount: 0)
        ]
        return Household(name: "Chen Family", inviteCode: "WV-7X42-PR9", members: members)
    }()

    // MARK: Activity

    static let activity: [ActivityEntry] = [
        ActivityEntry(kind: .added,        actorName: "Jamie Chen",  actorInitials: "JC", actorAccentHex: "#0A84FF", title: "Added Samsung QN90C 65\" Neo QLED", detail: "Electronics · 3 year coverage", occurredAt: Date().addingTimeInterval(-900)),
        ActivityEntry(kind: .expiringSoon, actorName: "System",      actorInitials: "WV", actorAccentHex: "#FF9500", title: "LG WashTower expiring soon",        detail: "24 days remaining",             occurredAt: daysAgo(1)),
        ActivityEntry(kind: .claimed,      actorName: "Jamie Chen",  actorInitials: "JC", actorAccentHex: "#0A84FF", title: "Filed claim #CLM-2026-0412",        detail: "LG WashTower · Under Review",   occurredAt: daysAgo(4)),
        ActivityEntry(kind: .updated,      actorName: "Morgan Chen", actorInitials: "MC", actorAccentHex: "#FFC4A3", title: "Updated MacBook Pro notes",         detail: "AppleCare+ reference added",    occurredAt: daysAgo(6)),
        ActivityEntry(kind: .invited,      actorName: "Jamie Chen",  actorInitials: "JC", actorAccentHex: "#0A84FF", title: "Invited Alex Park",                 detail: "Role: Member",                  occurredAt: daysAgo(12))
    ]
}

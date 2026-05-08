import Foundation
import SwiftUI

enum HouseholdRole: String, CaseIterable, Codable, Identifiable {
    case owner   = "Owner"
    case admin   = "Admin"
    case member  = "Member"
    case viewer  = "Viewer"

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .owner:  return .purple
        case .admin:  return AppColors.brandBlue
        case .member: return AppColors.success
        case .viewer: return .gray
        }
    }
}

struct HouseholdMember: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var email: String
    var role: HouseholdRole
    var avatarInitials: String
    var accentHex: String
    var joinedDate: Date
    var itemCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        role: HouseholdRole,
        avatarInitials: String,
        accentHex: String,
        joinedDate: Date,
        itemCount: Int
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.avatarInitials = avatarInitials
        self.accentHex = accentHex
        self.joinedDate = joinedDate
        self.itemCount = itemCount
    }

    var accentColor: Color { Color(hex: accentHex) }
}

struct Household: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var inviteCode: String
    var members: [HouseholdMember]

    init(id: UUID = UUID(), name: String, inviteCode: String, members: [HouseholdMember]) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.members = members
    }
}

enum ActivityKind: String, Codable {
    case added, updated, claimed, invited, expiringSoon

    var symbolName: String {
        switch self {
        case .added:         return "plus.circle.fill"
        case .updated:       return "pencil.circle.fill"
        case .claimed:       return "doc.badge.plus"
        case .invited:       return "person.crop.circle.badge.plus"
        case .expiringSoon:  return "clock.badge.exclamationmark.fill"
        }
    }

    var tint: Color {
        switch self {
        case .added:         return AppColors.success
        case .updated:       return AppColors.brandBlue
        case .claimed:       return .purple
        case .invited:       return .orange
        case .expiringSoon:  return AppColors.warning
        }
    }
}

struct ActivityEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: ActivityKind
    var actorName: String
    var actorInitials: String
    var actorAccentHex: String
    var title: String
    var detail: String
    var occurredAt: Date

    init(
        id: UUID = UUID(),
        kind: ActivityKind,
        actorName: String,
        actorInitials: String,
        actorAccentHex: String,
        title: String,
        detail: String,
        occurredAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.actorName = actorName
        self.actorInitials = actorInitials
        self.actorAccentHex = actorAccentHex
        self.title = title
        self.detail = detail
        self.occurredAt = occurredAt
    }

    var actorAccent: Color { Color(hex: actorAccentHex) }
}

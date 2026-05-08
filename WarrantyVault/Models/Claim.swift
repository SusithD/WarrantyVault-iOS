import Foundation
import SwiftUI

enum ClaimStatus: String, Codable {
    case submitted    = "Submitted"
    case underReview  = "Under Review"
    case approved     = "Approved"
    case completed    = "Completed"
    case rejected     = "Rejected"

    var tint: Color {
        switch self {
        case .submitted:   return .blue
        case .underReview: return AppColors.warning
        case .approved:    return AppColors.success
        case .completed:   return AppColors.success
        case .rejected:    return AppColors.danger
        }
    }

    var softTint: Color {
        switch self {
        case .submitted:   return .blue.opacity(0.12)
        case .underReview: return AppColors.warningSoft
        case .approved:    return AppColors.successSoft
        case .completed:   return AppColors.successSoft
        case .rejected:    return AppColors.dangerSoft
        }
    }
}

struct ClaimTimelineEvent: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var subtitle: String
    var date: Date
    var isDone: Bool

    init(id: UUID = UUID(), title: String, subtitle: String, date: Date, isDone: Bool) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.date = date
        self.isDone = isDone
    }
}

struct Claim: Identifiable, Hashable, Codable {
    let id: UUID
    var referenceCode: String
    var warrantyID: UUID
    var productName: String
    var issueSummary: String
    var status: ClaimStatus
    var filedDate: Date
    var updatedDate: Date
    var timeline: [ClaimTimelineEvent]

    init(
        id: UUID = UUID(),
        referenceCode: String,
        warrantyID: UUID,
        productName: String,
        issueSummary: String,
        status: ClaimStatus,
        filedDate: Date,
        updatedDate: Date,
        timeline: [ClaimTimelineEvent]
    ) {
        self.id = id
        self.referenceCode = referenceCode
        self.warrantyID = warrantyID
        self.productName = productName
        self.issueSummary = issueSummary
        self.status = status
        self.filedDate = filedDate
        self.updatedDate = updatedDate
        self.timeline = timeline
    }
}

struct ChatMessage: Identifiable, Hashable, Codable {
    let id: UUID
    var text: String
    var isFromUser: Bool
    var sentAt: Date
    var agentName: String?

    init(id: UUID = UUID(), text: String, isFromUser: Bool, sentAt: Date, agentName: String? = nil) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.sentAt = sentAt
        self.agentName = agentName
    }
}

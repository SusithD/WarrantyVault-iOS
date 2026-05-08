//
//  StatusTag.swift
//  WarrantyVault
//
//  Dark-theme status indicator. Each status reads as a small chip with a
//  colored dot + status-tinted text on a soft dark surface. The whole tag
//  sits flat on a dark card without competing with the lime brand accent.
//

import SwiftUI

struct StatusTag: View {
    let status: WarrantyStatus
    let daysRemaining: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.tint)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(status.tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppColors.bgSurfaceHi)
        )
        // Announce as a single utterance: "Status: Active, 312 days remaining"
        // rather than three separate elements (dot + text fragments).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    /// Spoken form for VoiceOver. Plain English, not the truncated visual label.
    private var accessibilityDescription: String {
        switch status {
        case .active:       return "Status: Active, \(daysRemaining) days remaining"
        case .expiringSoon: return "Status: Expiring soon, \(max(daysRemaining, 0)) days left"
        case .expired:      return "Status: Expired \(abs(daysRemaining)) days ago"
        }
    }

    private var label: String {
        switch status {
        case .active:       return "ACTIVE · \(daysRemaining)D"
        case .expiringSoon: return "EXPIRES IN \(max(daysRemaining, 0))D"
        case .expired:      return "EXPIRED \(abs(daysRemaining))D AGO"
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusTag(status: .active, daysRemaining: 312)
        StatusTag(status: .expiringSoon, daysRemaining: 24)
        StatusTag(status: .expired, daysRemaining: -12)
    }
    .padding()
    .background(GradientBackground())
}

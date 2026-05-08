//
//  StatusTag.swift
//  WarrantyVault
//
//  Refined status indicator. Replaces the previous filled-pastel pill
//  (`StatusChip`) with a quieter hairline-bordered tag carrying a small
//  colored dot and status-tinted text. The whole tag reads as data, not
//  decoration — list rows look composed instead of like badge collections.
//

import SwiftUI

struct StatusTag: View {
    let status: WarrantyStatus
    let daysRemaining: Int

    var body: some View {
        HStack(spacing: 5) {
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
                .fill(status.softTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(status.tint.opacity(0.18), lineWidth: 0.5)
        )
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

//
//  GlassCard.swift
//  WarrantyVault
//
//  Refined card container. Subtler shadow, hairline (0.5pt) border, and a
//  smaller default corner radius (16pt) — the previous 24pt felt soft and
//  iOS-default. The default padding is also 16pt so cards feel composed
//  rather than over-padded.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
    }
}

#Preview {
    ZStack {
        GradientBackground()
        VStack(spacing: 16) {
            GlassCard {
                Text("Refined card")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
            }
            GlassCard(padding: 20, cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Larger card with custom radius")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Caption text")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding()
    }
}

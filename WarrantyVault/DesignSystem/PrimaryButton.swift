//
//  PrimaryButton.swift
//  WarrantyVault
//
//  Refined: single solid fill (no gradient), 14pt corner radius (was 26 — too
//  pill-shaped), 12pt-blur shadow at 20% accent (was 12pt @ 25% — slightly
//  shorter elevation reads more "considered"). Touch state dims to 90%.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(AppTypography.button)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.brandBlue)
            )
            .shadow(color: AppColors.brandBlue.opacity(0.20), radius: 10, x: 0, y: 4)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .disabled(!isEnabled)
        .buttonStyle(PressDimStyle())
    }
}

/// Press feedback: 90% opacity on touch-down. Subtler than a scale animation,
/// reads as "I felt your tap" without bouncing.
private struct PressDimStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

struct SecondaryTextButton: View {
    let title: String
    var color: Color = AppColors.textSecondary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(PressDimStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Get Started", icon: "arrow.right") { }
        PrimaryButton(title: "Save Warranty") { }
        PrimaryButton(title: "Disabled", isEnabled: false) { }
        SecondaryTextButton(title: "SKIP") { }
    }
    .padding()
    .background(GradientBackground())
}

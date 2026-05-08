//
//  IconBadge.swift
//  WarrantyVault
//
//  Unified "icon in a rounded tile" component. Replaces the dozens of
//  one-off ZStack-with-Circle/RoundedRectangle blocks scattered through the
//  views. Keeps icon size, weight, and tile geometry consistent across the
//  app so badges in the dashboard, detail page, profile rows, and category
//  pickers all read at the same visual weight.
//

import SwiftUI

struct IconBadge: View {
    let symbol: String
    var tint: Color = AppColors.brandBlue
    var style: Style = .soft
    var size: Size = .medium
    var shape: Shape = .rounded

    enum Style {
        /// Soft tinted background, full-saturation icon. The default.
        case soft
        /// Solid tint background, white icon.
        case solid
        /// Hairline-bordered, transparent background, tinted icon.
        case outline
    }

    enum Size {
        case small   // 32 tile, 13 icon
        case medium  // 40 tile, 15 icon
        case large   // 56 tile, 22 icon

        var tile: CGFloat {
            switch self {
            case .small: 32
            case .medium: 40
            case .large: 56
            }
        }
        var icon: CGFloat {
            switch self {
            case .small: 13
            case .medium: 15
            case .large: 22
            }
        }
        var radius: CGFloat {
            switch self {
            case .small: 8
            case .medium: 10
            case .large: 14
            }
        }
    }

    enum Shape { case rounded, circle }

    var body: some View {
        ZStack {
            shapeView
            Image(systemName: symbol)
                .font(.system(size: size.icon, weight: .semibold))
                .foregroundStyle(iconColor)
        }
        .frame(width: size.tile, height: size.tile)
    }

    @ViewBuilder
    private var shapeView: some View {
        switch shape {
        case .circle:
            Circle().fill(backgroundFill)
                .overlay(Circle().stroke(borderStroke, lineWidth: borderWidth))
        case .rounded:
            RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                .fill(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                        .stroke(borderStroke, lineWidth: borderWidth)
                )
        }
    }

    private var backgroundFill: Color {
        switch style {
        case .soft:    return tint.opacity(0.10)
        case .solid:   return tint
        case .outline: return Color.clear
        }
    }

    private var iconColor: Color {
        switch style {
        case .soft, .outline: return tint
        case .solid:          return .white
        }
    }

    private var borderStroke: Color {
        style == .outline ? AppColors.border : .clear
    }
    private var borderWidth: CGFloat {
        style == .outline ? 0.5 : 0
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            IconBadge(symbol: "tv.inset.filled", tint: AppColors.brandBlue, style: .soft)
            IconBadge(symbol: "checkmark", tint: AppColors.success, style: .solid)
            IconBadge(symbol: "bell", tint: AppColors.textSecondary, style: .outline)
        }
        HStack(spacing: 12) {
            IconBadge(symbol: "tv.inset.filled", size: .small)
            IconBadge(symbol: "tv.inset.filled", size: .medium)
            IconBadge(symbol: "tv.inset.filled", size: .large)
        }
        HStack(spacing: 12) {
            IconBadge(symbol: "person.crop.circle", style: .soft, shape: .circle)
            IconBadge(symbol: "person.crop.circle", style: .solid, shape: .circle)
        }
    }
    .padding()
    .background(GradientBackground())
}

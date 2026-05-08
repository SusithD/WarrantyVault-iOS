import SwiftUI

struct IconBadge: View {
    let symbol: String
    var tint: Color = AppColors.accent
    var style: Style = .soft
    var size: Size = .medium
    var shape: Shape = .rounded

    enum Style { case soft, solid, outline }

    enum Size {
        case small   // 32 tile, 13 icon
        case medium  // 40 tile, 15 icon
        case large   // 56 tile, 22 icon

        var tile: CGFloat { self == .small ? 32 : self == .medium ? 40 : 56 }
        var icon: CGFloat { self == .small ? 13 : self == .medium ? 15 : 22 }
        var radius: CGFloat { self == .small ? 8 : self == .medium ? 10 : 14 }
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
        // Decorative by default — the parent row/button already carries a
        // meaningful label so VoiceOver shouldn't say "tv inset filled icon"
        // before reading the actual product name.
        .accessibilityHidden(true)
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
        case .soft:    return AppColors.bgSurfaceHi
        case .solid:   return tint
        case .outline: return Color.clear
        }
    }

    private var iconColor: Color {
        switch style {
        case .soft, .outline: return tint
        case .solid:          return AppColors.textInverse
        }
    }

    private var borderStroke: Color {
        style == .outline ? AppColors.borderSubtle : .clear
    }
    private var borderWidth: CGFloat {
        style == .outline ? 1 : 0
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            IconBadge(symbol: "tv.inset.filled", tint: Color(hex: "60A5FA"), style: .soft)
            IconBadge(symbol: "checkmark", tint: AppColors.accent, style: .solid)
            IconBadge(symbol: "bell", tint: AppColors.textPrimary, style: .outline)
        }
        HStack(spacing: 12) {
            IconBadge(symbol: "tv.inset.filled", size: .small)
            IconBadge(symbol: "tv.inset.filled", size: .medium)
            IconBadge(symbol: "tv.inset.filled", size: .large)
        }
    }
    .padding()
    .background(GradientBackground())
}

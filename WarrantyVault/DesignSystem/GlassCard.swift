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
                    .fill(AppColors.bgSurface)
            )
    }
}

typealias Panel = GlassCard

/// 1px hairline used inside dark cards for separating internal sections.
struct HairlineDivider: View {
    var color: Color = AppColors.borderSubtle
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

/// ALL-CAPS overline + small bottom padding, used at the top of any
/// section/card: "WARRANTY", "COVERAGE", "RECEIPT".
struct SectionHeader: View {
    let title: String
    var trailing: AnyView? = nil

    init(_ title: String, trailing: AnyView? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .overlineStyle()
            Spacer()
            if let trailing { trailing }
        }
        .padding(.bottom, 4)
    }
}

#Preview {
    ZStack {
        GradientBackground()
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Warranty")
                    Text("MacBook Pro 14\" M3")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    HairlineDivider()
                    Text("AppleCare+ included")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding()
    }
}

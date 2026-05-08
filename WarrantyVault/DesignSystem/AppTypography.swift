import SwiftUI

enum AppTypography {


    static let display      = Font.system(size: 34, weight: .heavy,    design: .default).leading(.tight)
    static let largeTitle   = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title        = Font.system(.title,      design: .default).weight(.bold)
    static let headline     = Font.system(.headline,   design: .default).weight(.semibold)
    static let subhead      = Font.system(.subheadline, design: .default).weight(.semibold)


    static let body         = Font.system(.body,    design: .default)
    static let bodyStrong   = Font.system(.body,    design: .default).weight(.semibold)
    static let caption      = Font.system(.caption, design: .default).weight(.medium)
    static let captionStrong = Font.system(.caption, design: .default).weight(.semibold)


    static let overline     = Font.system(.caption2, design: .default).weight(.heavy)


    static let chip         = Font.system(.caption, design: .default).weight(.semibold)


    static let button       = Font.system(.body, design: .default).weight(.semibold)


    static let mono         = Font.system(.footnote, design: .monospaced)

    static let monoBold     = Font.system(.footnote, design: .monospaced).weight(.semibold)
}

extension Text {


    func overlineStyle(color: Color = AppColors.textSecondary) -> some View {
        self
            .font(AppTypography.overline)
            .tracking(1.0)
            .foregroundStyle(color)
    }


    func displayStyle(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(AppTypography.display)
            .tracking(-0.8)
            .foregroundStyle(color)
    }
}

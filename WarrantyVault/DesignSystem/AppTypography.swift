import SwiftUI

enum AppTypography {

    // Each token uses `relativeTo:` so the size scales with the user's
    // Dynamic Type setting. The numeric size is the *default* (Large) — at
    // smaller settings the system shrinks them, at AX5 they grow up to ~310%.
    // Anchoring each role to a TextStyle (`.title`, `.body`, etc.) keeps
    // the proportional rhythm intact across the entire scale.

    // MARK: Display & structural
    static let display      = Font.system(size: 34, weight: .heavy,    design: .default).leading(.tight)
    static let largeTitle   = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title        = Font.system(.title,      design: .default).weight(.bold)
    static let headline     = Font.system(.headline,   design: .default).weight(.semibold)
    static let subhead      = Font.system(.subheadline, design: .default).weight(.semibold)

    // MARK: Body & captions
    static let body         = Font.system(.body,    design: .default)
    static let bodyStrong   = Font.system(.body,    design: .default).weight(.semibold)
    static let caption      = Font.system(.caption, design: .default).weight(.medium)
    static let captionStrong = Font.system(.caption, design: .default).weight(.semibold)

    /// ALL-CAPS overlines used as section headers ("WARRANTY", "COVERAGE").
    /// Anchored to caption2 so it scales but stays small relative to body.
    static let overline     = Font.system(.caption2, design: .default).weight(.heavy)

    /// Capsule / chip text.
    static let chip         = Font.system(.caption, design: .default).weight(.semibold)

    /// Primary button label.
    static let button       = Font.system(.body, design: .default).weight(.semibold)

    // MARK: Mono — sparingly applied to records/values
    /// Serials, refs, dates.
    static let mono         = Font.system(.footnote, design: .monospaced)
    /// Prices, totals, hero numbers when monospaced rhythm helps alignment.
    static let monoBold     = Font.system(.footnote, design: .monospaced).weight(.semibold)
}

extension Text {
    /// ALL-CAPS overline used at the top of every panel / section.
    /// Tracking +1.0, weight Heavy — reads as an engraved label, not body text.
    func overlineStyle(color: Color = AppColors.textSecondary) -> some View {
        self
            .font(AppTypography.overline)
            .tracking(1.0)
            .foregroundStyle(color)
    }

    /// Display-size hero number — used for stats like "7 active warranties".
    /// Tightens tracking and locks weight to Heavy for a "set" feel.
    func displayStyle(color: Color = AppColors.textPrimary) -> some View {
        self
            .font(AppTypography.display)
            .tracking(-0.8)
            .foregroundStyle(color)
    }
}

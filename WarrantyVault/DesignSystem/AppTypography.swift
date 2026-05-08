//
//  AppTypography.swift
//  WarrantyVault
//
//  Refined typography. Two families:
//   - SF Pro for everything readable.
//   - SF Mono — used sparingly for data values that benefit from the
//     ledger-y feel: serial numbers, claim references, dates, prices.
//
//  Tracking is tight on the display end (-0.5/-0.3) for a more set,
//  composed feel. Overlines push to Heavy + +1.0 tracking for an
//  "engraved label" treatment used as section headers.
//

import SwiftUI

enum AppTypography {

    // MARK: Display & structural
    static let display      = Font.system(size: 34, weight: .heavy)
    static let largeTitle   = Font.system(size: 28, weight: .bold)
    static let title        = Font.system(size: 26, weight: .bold)
    static let headline     = Font.system(size: 20, weight: .semibold)
    static let subhead      = Font.system(size: 17, weight: .semibold)

    // MARK: Body & captions
    static let body         = Font.system(size: 15, weight: .regular)
    static let bodyStrong   = Font.system(size: 15, weight: .semibold)
    static let caption      = Font.system(size: 12, weight: .medium)
    static let captionStrong = Font.system(size: 12, weight: .semibold)

    /// ALL-CAPS overlines used as section headers ("WARRANTY", "COVERAGE").
    static let overline     = Font.system(size: 10, weight: .heavy)

    /// Capsule / chip text.
    static let chip         = Font.system(size: 12, weight: .semibold)

    /// Primary button label.
    static let button       = Font.system(size: 15, weight: .semibold)

    // MARK: Mono — sparingly applied to records/values
    /// Serials, refs, dates.
    static let mono         = Font.system(size: 13, weight: .regular, design: .monospaced)
    /// Prices, totals, hero numbers when monospaced rhythm helps alignment.
    static let monoBold     = Font.system(size: 14, weight: .semibold, design: .monospaced)
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

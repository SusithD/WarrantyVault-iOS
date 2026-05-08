//
//  AppColors.swift
//  WarrantyVault
//
//  Dark + Electric-Lime palette. Pure black background, dark grey surfaces,
//  bright lime accent. Status hierarchy: lime is `success` (and the brand
//  itself), warning is amber, danger is hot pink-red.
//
//  The legacy token name `brandBlue` is retained for callsite compatibility
//  but now resolves to the lime accent — a future rename pass can clean
//  this up. The `*Soft` variants resolve to neutral dark surfaces; they're
//  no longer pastel tints of their parent color.
//

import SwiftUI

enum AppColors {

    // MARK: Background ladder (3 levels)
    /// Whole-screen background. Pure OLED black.
    static let bgApp        = Color(hex: "000000")
    /// Default surface for cards, input fields, code-tile boxes, social buttons.
    static let bgSurface    = Color(hex: "1A1A1A")
    /// Raised within a card — pressed states, focused inputs, secondary panels.
    static let bgSurfaceHi  = Color(hex: "262626")
    /// Top-most surfaces — modals, sheets, action sheets.
    static let bgSurfaceMax = Color(hex: "303030")

    // MARK: Borders (rare — hierarchy is mostly via background contrast)
    static let borderSubtle = Color(hex: "2A2A2A")
    static let borderBold   = Color(hex: "404040")

    // MARK: Text
    static let textPrimary   = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "9CA3AF")  // Gray-400
    static let textTertiary  = Color(hex: "6B7280")  // Gray-500
    /// Text on lime fills.
    static let textInverse   = Color(hex: "000000")

    // MARK: Accent — electric lime (the brand)
    /// Signature accent. Used on primary CTAs and as the success status.
    static let accent      = Color(hex: "C7FF4D")
    /// Pressed / disabled state of accent fills.
    static let accentDim   = Color(hex: "9DCC2E")

    // MARK: Status hierarchy
    /// Success === brand. Lime green on dark reads as "active / good / done".
    static let success = accent
    /// Warning → amber.
    static let warning = Color(hex: "FBBF24")  // Amber-400
    /// Danger → hot pink-red. Less iOS-stock than red-600.
    static let danger  = Color(hex: "FF4D6D")
    /// Decorative purple, used for category tints (not system signal).
    static let purple  = Color(hex: "A78BFA")  // Violet-400

    // MARK: - Backwards-compat aliases (deprecated)
    /// Legacy token name; now points at the lime accent. Future rename
    /// pass can swap callsites to `accent` directly.
    static let brandBlue       = accent
    static let brandBlueDim    = accentDim

    /// `*Soft` was previously a pastel tint of its parent color. In the dark
    /// palette, those slots become a neutral dark surface so the icon ladders
    /// don't paint bright pastel circles all over the UI. Status `Soft`
    /// variants stay status-tinted but very dim — used as dark backgrounds
    /// for tags, never decoration.
    static let brandBlueSoft   = bgSurface
    static let purpleSoft      = bgSurface
    /// Status soft = surface (the colored tag draws its identity from the dot
    /// + text + a subtle status-tinted border, not from a pastel fill).
    static let successSoft     = bgSurface
    static let warningSoft     = bgSurface
    static let dangerSoft      = bgSurface

    /// Old gradient stops. Resolve to bgApp so any leftover gradient renders
    /// as a flat black surface.
    static let bgGradientStart = bgApp
    static let bgGradientEnd   = bgApp

    /// Old neutral surfaces.
    static let surface      = bgSurface
    static let surfaceMuted = bgSurfaceHi
    static let border       = borderSubtle
    static let borderStrong = borderBold
}

extension Color {
    /// Initialise a Color from a hex string. Supports "#RGB", "#RRGGBB", and "#AARRGGBB".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#")).uppercased()
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6:  // RRGGBB (24-bit)
            (a, r, g, b) = (255, value >> 16, value >> 8 & 0xFF, value & 0xFF)
        case 8:  // AARRGGBB (32-bit)
            (a, r, g, b) = (value >> 24, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

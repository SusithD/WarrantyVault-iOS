//
//  AppColors.swift
//  WarrantyVault
//
//  Refined light palette. Brand blue retained; status colors muted from
//  iOS-stock to deeper, more considered hues. Neutrals are slate-leaning
//  with a hint of warmth on the surface tones (Stone-50/100), so the
//  whole composition reads as "designed" rather than "default."
//
//  The `*Soft` variants stay around for status backgrounds (used sparingly)
//  but the brand-blue soft tint is now meant for hover/selected states only,
//  not as decoration on every icon background.
//

import SwiftUI

enum AppColors {

    // MARK: Backgrounds — warm whites, not cool blue-whites
    static let bgGradientStart = Color(hex: "FAFAF9")  // Stone-50
    static let bgGradientEnd   = Color(hex: "F5F5F4")  // Stone-100
    static let surface         = Color.white
    /// Muted surface used for input fields and inset blocks.
    static let surfaceMuted    = Color(hex: "F8FAFC")  // Slate-50

    // MARK: Text — slate scale, cooler than the previous greys
    static let textPrimary     = Color(hex: "0F172A")  // Slate-900
    static let textSecondary   = Color(hex: "64748B")  // Slate-500
    static let textTertiary    = Color(hex: "94A3B8")  // Slate-400

    // MARK: Borders / dividers
    static let border          = Color(hex: "E2E8F0")  // Slate-200
    static let borderStrong    = Color(hex: "CBD5E1")  // Slate-300 — used sparingly

    // MARK: Brand
    /// Same iOS-blue we've always used. Recognisable; keep.
    static let brandBlue       = Color(hex: "0A84FF")
    /// Reserved for selected / pressed / focused states only — NOT decoration.
    static let brandBlueSoft   = Color(hex: "EFF6FF")  // Blue-50, much softer than before

    // MARK: Status — muted from iOS-stock to deeper, less playful hues
    /// Success → emerald, deeper than iOS green.
    static let success         = Color(hex: "16A34A")  // Green-600
    static let successSoft     = Color(hex: "DCFCE7")  // Green-100

    /// Warning → amber, less playful than iOS orange.
    static let warning         = Color(hex: "D97706")  // Amber-600
    static let warningSoft     = Color(hex: "FEF3C7")  // Amber-100

    /// Danger → brick, less fire-engine than iOS red.
    static let danger          = Color(hex: "DC2626")  // Red-600
    static let dangerSoft      = Color(hex: "FEE2E2")  // Red-100

    /// Accent → violet, for category badges only.
    static let purple          = Color(hex: "7C3AED")  // Violet-600
    static let purpleSoft      = Color(hex: "EDE9FE")  // Violet-100
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

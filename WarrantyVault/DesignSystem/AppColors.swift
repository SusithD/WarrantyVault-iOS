import SwiftUI

enum AppColors {


    static let bgApp        = Color(hex: "000000")

    static let bgSurface    = Color(hex: "1A1A1A")

    static let bgSurfaceHi  = Color(hex: "262626")

    static let bgSurfaceMax = Color(hex: "303030")


    static let borderSubtle = Color(hex: "2A2A2A")
    static let borderBold   = Color(hex: "404040")


    static let textPrimary   = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "9CA3AF")
    static let textTertiary  = Color(hex: "6B7280")

    static let textInverse   = Color(hex: "000000")


    static let accent      = Color(hex: "C7FF4D")

    static let accentDim   = Color(hex: "9DCC2E")


    static let success = accent

    static let warning = Color(hex: "FBBF24")

    static let danger  = Color(hex: "FF4D6D")

    static let purple  = Color(hex: "A78BFA")


    static let brandBlue       = accent
    static let brandBlueDim    = accentDim


    static let brandBlueSoft   = bgSurface
    static let purpleSoft      = bgSurface


    static let successSoft     = bgSurface
    static let warningSoft     = bgSurface
    static let dangerSoft      = bgSurface


    static let bgGradientStart = bgApp
    static let bgGradientEnd   = bgApp


    static let surface      = bgSurface
    static let surfaceMuted = bgSurfaceHi
    static let border       = borderSubtle
    static let borderStrong = borderBold
}

extension Color {

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#")).uppercased()
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, value >> 16, value >> 8 & 0xFF, value & 0xFF)
        case 8:
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

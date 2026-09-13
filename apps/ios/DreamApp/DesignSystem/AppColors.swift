import SwiftUI

/// Global color tokens from `docs/design.md`. The app is dark-only, so these
/// are fixed values rather than adaptive assets.
enum AppColors {
    static let text = Color(hex: 0xFFFFFF)
    static let background = Color(hex: 0x151C26)
    static let backgroundElement = Color(hex: 0x1E2949)
    static let backgroundSelected = Color(hex: 0x2E3135)
    static let textSecondary = Color(hex: 0xB0B4BA)
    static let accent = Color(hex: 0x62B0FF)
    static let accentSoft = Color(hex: 0x173B5C)
}

extension Color {
    /// Builds an sRGB color from a `0xRRGGBB` literal.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

import SwiftUI

// Palette ported from the Android app's ui/theme/Theme.kt so the two platforms read as the
// same product. Light/dark resolved by the system; SwiftUI picks the right one per Color.
enum Palette {
    static let primary       = Color(light: 0x1976D2, dark: 0x64B5F6)
    static let onPrimary     = Color(light: 0xFFFFFF, dark: 0x0D47A1)
    static let recording     = Color(hex: 0xE53935)          // matches Android's mic-active red
    static let error         = Color(light: 0xD32F2F, dark: 0xCF6679)
    static let background     = Color(light: 0xFAFAFA, dark: 0x121212)
    static let surface        = Color(light: 0xFFFFFF, dark: 0x1E1E1E)
    static let surfaceVariant = Color(light: 0xECECEC, dark: 0x2A2A2A)
    static let onSurfaceVariant = Color(light: 0x49454F, dark: 0xCAC4D0)
    static let onBackground   = Color(light: 0x1C1B1F, dark: 0xE6E1E5)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Distinct hex per appearance, resolved dynamically like Android's light/dark schemes.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red:   CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue:  CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

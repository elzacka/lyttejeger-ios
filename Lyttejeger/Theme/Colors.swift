import SwiftUI

extension Color {
    // MARK: - Primary Palette (Light mode only)

    /// Warm beige background - #F4F1EA
    static let appBackground = Color(red: 0.957, green: 0.945, blue: 0.918)

    /// Dark text - #2C2C2C
    static let appForeground = Color(red: 0.173, green: 0.173, blue: 0.173)

    /// Teal accent - #1A5F7A
    static let appAccent = Color(red: 0.102, green: 0.373, blue: 0.478)

    /// Teal accent hover - #134A5F
    static let appAccentHover = Color(red: 0.075, green: 0.290, blue: 0.373)

    /// Muted background - #EBE7DE
    static let appMuted = Color(red: 0.922, green: 0.906, blue: 0.871)

    /// Muted foreground - #4A4A4A (WCAG AA 4.5:1 on all app backgrounds)
    static let appMutedForeground = Color(red: 0.290, green: 0.290, blue: 0.290)

    /// Border color - #D4D0C6
    static let appBorder = Color(red: 0.831, green: 0.816, blue: 0.776)

    /// Error - #9B2915
    static let appError = Color(red: 0.608, green: 0.161, blue: 0.082)

    /// Success - #3D6649
    static let appSuccess = Color(red: 0.239, green: 0.400, blue: 0.286)

    /// Card background - white with slight warmth
    static let appCard = Color.white

    /// Input background
    static let appInput = Color.white
}

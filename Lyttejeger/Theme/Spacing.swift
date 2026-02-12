import SwiftUI

enum AppSpacing {
    /// 4px base grid
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum AppRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let full: CGFloat = 9999
}

enum AppSize {
    /// Minimum touch target (WCAG 2.2 AA)
    static let touchTarget: CGFloat = 44

    /// Podcast artwork in cards
    static let artworkSmall: CGFloat = 56

    /// Podcast artwork in detail view
    static let artworkMedium: CGFloat = 120

    /// Podcast artwork in player
    static let artworkLarge: CGFloat = 280

    /// Mini player height
    static let miniPlayerHeight: CGFloat = 80

    /// Tab bar icon size
    static let tabIcon: CGFloat = 24

    /// Player main button (play/pause)
    static let playerMainButton: CGFloat = 64
}

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

    /// Podcast artwork in the følgeliste grid. Three of these plus their
    /// spacing and the page padding fill an iPhone width, so the cover and its
    /// title share one column edge to edge.
    static let artworkGrid: CGFloat = 106

    /// The same grid at accessibility text sizes, where it drops to a single
    /// column so long podcast names fit without breaking mid-word.
    static let artworkGridWide: CGFloat = 165

    /// Mini player height
    static let miniPlayerHeight: CGFloat = 80

    /// Tab bar icon size
    static let tabIcon: CGFloat = 24

    /// Player main button (play/pause)
    static let playerMainButton: CGFloat = 64
}

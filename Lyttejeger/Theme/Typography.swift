import SwiftUI

extension Font {
    // MARK: - DM Mono Typography

    /// DM Mono with Dynamic Type support
    static func dmMono(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: TextStyle = .body) -> Font {
        switch weight {
        case .light:
            return .custom("DMMono-Light", size: size, relativeTo: style)
        case .medium, .semibold, .bold:
            return .custom("DMMono-Medium", size: size, relativeTo: style)
        default:
            return .custom("DMMono-Regular", size: size, relativeTo: style)
        }
    }

    // MARK: - Semantic Font Styles (with Dynamic Type scaling)

    /// Page title - 24pt medium
    static let pageTitle = Font.custom("DMMono-Medium", size: 24, relativeTo: .title)

    /// Section heading - 18pt medium
    static let sectionTitle = Font.custom("DMMono-Medium", size: 18, relativeTo: .headline)

    /// Card title - 15pt medium
    static let cardTitle = Font.custom("DMMono-Medium", size: 15, relativeTo: .subheadline)

    /// Body text - 15pt regular
    static let bodyText = Font.custom("DMMono-Regular", size: 15, relativeTo: .body)

    /// Small text - 12pt regular
    static let smallText = Font.custom("DMMono-Regular", size: 12, relativeTo: .footnote)

    /// Caption - 11pt light
    static let caption2Text = Font.custom("DMMono-Light", size: 11, relativeTo: .caption2)

    /// Tab bar label - 10pt regular
    static let tabLabel = Font.custom("DMMono-Regular", size: 10, relativeTo: .caption2)

    /// Button text - 14pt medium
    static let buttonText = Font.custom("DMMono-Medium", size: 14, relativeTo: .body)

    /// Badge text - 11pt medium
    static let badgeText = Font.custom("DMMono-Medium", size: 11, relativeTo: .caption2)

    /// Player time - 13pt regular (monospaced for alignment)
    static let playerTime = Font.custom("DMMono-Regular", size: 13, relativeTo: .caption)

    /// Speed indicator - 13pt medium
    static let speedText = Font.custom("DMMono-Medium", size: 13, relativeTo: .caption)
}

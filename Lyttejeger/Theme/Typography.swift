import SwiftUI

extension Font {
    // MARK: - Semantic Font Styles (with Dynamic Type scaling)

    /// Page title - 24pt medium
    static let pageTitle = Font.custom("DMMono-Medium", size: 24, relativeTo: .title)

    /// Section heading - 18pt medium
    static let sectionTitle = Font.custom("DMMono-Medium", size: 18, relativeTo: .headline)

    /// Card title - 13pt medium
    static let cardTitle = Font.custom("DMMono-Medium", size: 13, relativeTo: .subheadline)

    /// Body text - 15pt regular
    static let bodyText = Font.custom("DMMono-Regular", size: 15, relativeTo: .body)

    /// Small text - 12pt regular
    static let smallText = Font.custom("DMMono-Regular", size: 12, relativeTo: .footnote)

    /// Caption - 11pt light
    static let caption2Text = Font.custom("DMMono-Light", size: 11, relativeTo: .caption2)

    /// Button text - 14pt medium
    static let buttonText = Font.custom("DMMono-Medium", size: 14, relativeTo: .body)

    /// Badge text - 11pt medium
    static let badgeText = Font.custom("DMMono-Medium", size: 11, relativeTo: .caption2)

    /// Player time - 13pt regular (monospaced for alignment)
    static let playerTime = Font.custom("DMMono-Regular", size: 13, relativeTo: .caption)

    /// Speed indicator - 13pt medium
    static let speedText = Font.custom("DMMono-Medium", size: 13, relativeTo: .caption)
}

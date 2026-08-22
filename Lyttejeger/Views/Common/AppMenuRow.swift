import SwiftUI

/// Standard menu row used across menu/settings sheets: one consistent
/// anatomy (optional icon, label, trailing glyph) so every row shares
/// height, padding, fonts and colors.
///
/// There is deliberately no explanatory subtitle. A settings row states what
/// it controls; what it means belongs in the user guide, which does not have
/// to say it in six words. Without one, every row settles on the same 44pt
/// height and the screen reads as one rhythm instead of a ragged column.
///
/// Trailing glyph vocabulary:
/// - `AppMenuRowChevron`: tapping navigates within the app
/// - `AppMenuRowExternal`: tapping opens something outside the app
/// - `AppMenuRowValue`: static right-aligned info (e.g. version)
struct AppMenuRow<Trailing: View>: View {
    var icon: String? = nil
    let label: String
    var iconColor: Color = .appAccent
    var labelColor: Color = .appForeground
    /// Dimmed and untappable while false, so a row that is busy says so
    /// instead of silently swallowing taps.
    var isEnabled: Bool = true
    var action: (() -> Void)? = nil
    /// Extra value VoiceOver should read, typically the content of a
    /// trailing `AppMenuRowValue`.
    var accessibilityValue: String? = nil
    var accessibilityHint: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        if let action {
            Button(action: action) {
                content
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
            .accessibilityLabel(accessibilityText)
            .accessibilityHint(accessibilityHint ?? "")
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)
        }
    }

    private var content: some View {
        HStack(spacing: AppSpacing.md) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(.callout))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }

            Text(label)
                .font(.smallText)
                .foregroundStyle(labelColor)
                .multilineTextAlignment(.leading)

            Spacer()

            trailing()
        }
        .padding(.vertical, AppSpacing.sm)
        .frame(minHeight: AppSize.touchTarget)
        .contentShape(Rectangle())
    }

    private var accessibilityText: String {
        var parts: [String] = [label]
        if let accessibilityValue, !accessibilityValue.isEmpty { parts.append(accessibilityValue) }
        return parts.joined(separator: ". ")
    }
}

extension AppMenuRow where Trailing == EmptyView {
    init(
        icon: String? = nil,
        label: String,
        iconColor: Color = .appAccent,
        labelColor: Color = .appForeground,
        isEnabled: Bool = true,
        action: (() -> Void)? = nil,
        accessibilityHint: String? = nil
    ) {
        self.icon = icon
        self.label = label
        self.iconColor = iconColor
        self.labelColor = labelColor
        self.isEnabled = isEnabled
        self.action = action
        self.accessibilityHint = accessibilityHint
        self.trailing = { EmptyView() }
    }
}

/// Chevron: tapping the row navigates within the app.
struct AppMenuRowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(Color.appMutedForeground)
            .accessibilityHidden(true)
    }
}

/// External-link arrow: tapping the row opens outside the app.
struct AppMenuRowExternal: View {
    var body: some View {
        Image(systemName: "arrow.up.right")
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(Color.appMutedForeground)
            .accessibilityHidden(true)
    }
}

/// Right-aligned static value (e.g. version number). Pair with
/// `accessibilityValue` on the row so VoiceOver reads it.
struct AppMenuRowValue: View {
    let value: String

    var body: some View {
        Text(value)
            .font(.smallText)
            .foregroundStyle(Color.appMutedForeground)
            .accessibilityHidden(true)
    }
}

/// Standard divider between rows in a card.
struct AppMenuRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.appBorder.opacity(0.3))
            .frame(height: 1)
    }
}

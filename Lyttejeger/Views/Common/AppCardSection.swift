import SwiftUI

/// Section with an uppercase header and a single card containing rows.
/// The one container pattern for menu/settings surfaces: content always
/// lives inside a card, headers always sit above it in the same style.
struct AppCardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption2Text)
                    .foregroundStyle(Color.appMutedForeground)
                    .textCase(.uppercase)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.bottom, AppSpacing.sm)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.appCard)
            .clipShape(.rect(cornerRadius: AppRadius.lg))
        }
    }
}

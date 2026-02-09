import SwiftUI

struct ExpandableText: View {
    let text: String
    var textFont: Font = .smallText
    var textColor: Color = .appMutedForeground
    var previewLines: Int = 2
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(text)
                .font(textFont)
                .foregroundStyle(textColor)
                .lineLimit(isExpanded ? nil : previewLines)

            Text(isExpanded ? "Vis mindre" : "Vis mer")
                .font(.caption2Text)
                .foregroundStyle(Color.appAccent)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if UIAccessibility.isReduceMotionEnabled {
                isExpanded.toggle()
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
        .accessibilityLabel(isExpanded ? "Skjul beskrivelse" : "Vis beskrivelse")
    }
}

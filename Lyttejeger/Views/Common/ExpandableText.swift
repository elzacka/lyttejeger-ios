import SwiftUI

struct ExpandableText: View {
    let text: String
    var textFont: Font = .smallText
    var textColor: Color = .appMutedForeground
    var previewLines: Int = 2
    @State private var isExpanded = false

    var body: some View {
        Text(text)
            .font(textFont)
            .foregroundStyle(textColor)
            .lineLimit(isExpanded ? nil : previewLines)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottomTrailing) {
                if !isExpanded {
                    LinearGradient(
                        colors: [textColor.opacity(0), textColor.opacity(0.15)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 20)
                    .allowsHitTesting(false)
                }
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

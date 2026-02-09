import SwiftUI

struct FormattedText: View {
    let text: String
    let lineLimit: Int?

    init(_ text: String, lineLimit: Int? = nil) {
        self.text = text
        self.lineLimit = lineLimit
    }

    var body: some View {
        Text(text)
            .font(.bodyText)
            .foregroundStyle(Color.appForeground)
            .lineLimit(lineLimit)
    }
}

#if DEBUG
#Preview {
    FormattedText("Eksempeltekst for forhandsvisning")
        .padding()
        .background(Color.appBackground)
}
#endif

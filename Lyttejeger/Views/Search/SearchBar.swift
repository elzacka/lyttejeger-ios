import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Søk etter podkaster..."

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.appMutedForeground)

            TextField(placeholder, text: $text)
                .font(.bodyText)
                .foregroundStyle(Color.appForeground)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appMutedForeground)
                }
                .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appInput)
        .clipShape(.rect(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
}

#if DEBUG
#Preview {
    SearchBar(text: .constant("podkast"))
        .padding()
        .background(Color.appBackground)
}
#endif

import SwiftUI

struct InnstillingerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showLastPlayed") private var showLastPlayed = true
    @AppStorage("showNewFromSubscriptions") private var showNewFromSubscriptions = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Section header
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "house")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appAccent)
                        Text("Hjem-skjerm")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appMutedForeground)
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Toggles card
                    VStack(spacing: 0) {
                        toggleRow(
                            title: "Fortsett å lytte",
                            subtitle: "Vis uferdig episode",
                            isOn: $showLastPlayed
                        )

                        Rectangle()
                            .fill(Color.appBorder.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, AppSpacing.lg)

                        toggleRow(
                            title: "Nytt fra Mine podder",
                            subtitle: "Episoder fra siste 7 dager",
                            isOn: $showNewFromSubscriptions
                        )
                    }
                    .background(Color.appCard)
                    .clipShape(.rect(cornerRadius: AppRadius.lg))

                    Text("Velg hva som vises på Hjem-skjermen når du ikke søker.")
                        .font(.caption2Text)
                        .foregroundStyle(Color.appMutedForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
            }
            .background(Color.appBackground)
            .navigationTitle("Innstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk") {
                        dismiss()
                    }
                    .font(.buttonText)
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.smallText)
                    .foregroundStyle(Color.appForeground)
                Text(subtitle)
                    .font(.caption2Text)
                    .foregroundStyle(Color.appMutedForeground)
            }
        }
        .tint(Color.appAccent)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }
}

#if DEBUG
#Preview {
    InnstillingerView()
}
#endif

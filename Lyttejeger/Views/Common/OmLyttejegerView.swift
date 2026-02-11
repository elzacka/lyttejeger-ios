import SwiftUI

struct OmLyttejegerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button("Lukk") { dismiss() }
                    .font(.buttonText)
                    .foregroundStyle(Color.appAccent)
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Hero
                    VStack(spacing: AppSpacing.md) {
                        Image("LaunchLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)

                        Text("Lyttejeger")
                            .font(.pageTitle)
                            .foregroundStyle(Color.appForeground)
                    }
                    .frame(maxWidth: .infinity)

                    // Description
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("En rolig podkastspiller som lar deg lytte i fred.")
                            .font(.bodyText)
                            .foregroundStyle(Color.appForeground)

                        Text("Ingen kontoer. Ingen sporing. Ingen annonser. Bare podkaster.")
                            .font(.smallText)
                            .foregroundStyle(Color.appMutedForeground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.lg)
                    .background(Color.appCard)
                    .clipShape(.rect(cornerRadius: AppRadius.lg))

                    // Credits
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "person")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.appAccent)
                            Text("Laget med")
                                .font(.caption2Text)
                                .foregroundStyle(Color.appMutedForeground)
                                .textCase(.uppercase)
                        }

                        creditRow("Swift & SwiftUI", detail: "Apples rammeverk for iOS")
                        creditRow("Podcast Index", detail: "Åpen podkast-katalog")
                        creditRow("sindrel/nrk-pod-feeds", detail: "NRK-podkaster via åpne RSS-feeder")
                        creditRow("DM Mono", detail: "Typografi av Colophon Foundry")
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .clipShape(.rect(cornerRadius: AppRadius.lg))

                    // Contact
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "envelope")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.appAccent)
                            Text("Kontakt")
                                .font(.caption2Text)
                                .foregroundStyle(Color.appMutedForeground)
                                .textCase(.uppercase)
                        }

                        creditRow("Tazk", detail: "hei@tazk.no")
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .clipShape(.rect(cornerRadius: AppRadius.lg))

                    // Footer
                    VStack(spacing: AppSpacing.xs) {
                        Image("LaunchLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .opacity(0.3)

                        Text("Lyttejeger \(AppConstants.appVersion)")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appBorder)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xxxl)
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
        .background(Color.appBackground)
    }

    private func creditRow(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.smallText)
                .foregroundStyle(Color.appForeground)
            Text(detail)
                .font(.caption2Text)
                .foregroundStyle(Color.appMutedForeground)
        }
    }
}

#if DEBUG
#Preview {
    OmLyttejegerView()
}
#endif

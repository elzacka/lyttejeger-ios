import SwiftUI
import SwiftData

struct OmLyttejegerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    private let privacyURL = URL(string: "https://github.com/elzacka/lyttejeger-ios/blob/main/Personvern.md")!
    private let guideURL = URL(string: "https://github.com/elzacka/lyttejeger-ios/blob/main/Brukerveiledning.md")!

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
            .padding(.horizontal, AppSpacing.xl)
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
                    Text("En rolig podkastspiller som lar deg lytte i fred")
                        .font(.smallText)
                        .foregroundStyle(Color.appMutedForeground)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    // Credits
                    card {
                        cardHeader("Laget med")

                        creditRow("Swift & SwiftUI", detail: "Apples rammeverk for iOS")
                        creditRow("Podcast Index", detail: "Åpen podkast-katalog")
                        creditRow("sindrel/nrk-pod-feeds", detail: "NRK-podkaster via åpne RSS-feeder")
                        creditRow("DM Mono", detail: "Typografi av Colophon Foundry")
                    }

                    // Contact
                    card {
                        cardHeader("Kontakt")

                        creditRow("Tazk", detail: "hei@tazk.no")
                    }

                    // Data management
                    card {
                        cardHeader("Dine data")

                        Button {
                            exportData()
                        } label: {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 14))
                                Text("Eksporter som JSON")
                                    .font(.smallText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.appBorder)
                            }
                            .foregroundStyle(Color.appAccent)
                            .padding(AppSpacing.md)
                            .background(Color.appBackground)
                            .clipShape(.rect(cornerRadius: AppRadius.sm))
                        }
                        .accessibilityLabel("Eksporter alle data som JSON-fil")

                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                Text("Slett alle data")
                                    .font(.smallText)
                                Spacer()
                            }
                            .foregroundStyle(Color.appError)
                            .padding(AppSpacing.md)
                            .background(Color.appBackground)
                            .clipShape(.rect(cornerRadius: AppRadius.sm))
                        }
                        .accessibilityLabel("Slett alle lokalt lagrede data")
                    }

                    // Links
                    VStack(spacing: AppSpacing.md) {
                        Button {
                            openURL(guideURL)
                        } label: {
                            Text("Brukerveiledning for søk og filter")
                                .font(.smallText)
                                .foregroundStyle(Color.appAccent)
                                .underline()
                        }

                        Button {
                            openURL(privacyURL)
                        } label: {
                            Text("Personvernerklæring")
                                .font(.smallText)
                                .foregroundStyle(Color.appAccent)
                                .underline()
                        }
                    }

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
        .alert("Slett alle data?", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) {}
            Button("Slett", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("Dette sletter alle abonnementer, spillekøen og avspillingsposisjoner. Handlingen kan ikke angres.")
        }
        .sheet(isPresented: $showExportSheet) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    // MARK: - Card Components

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            content()
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .clipShape(.rect(cornerRadius: AppRadius.lg))
    }

    private func cardHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2Text)
            .foregroundStyle(Color.appMutedForeground)
            .textCase(.uppercase)
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

    // MARK: - Data Export

    private func exportData() {
        let context = modelContext

        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        let queueItems = (try? context.fetch(FetchDescriptor<QueueItem>(sortBy: [SortDescriptor(\.position)]))) ?? []
        let positions = (try? context.fetch(FetchDescriptor<PlaybackPosition>())) ?? []

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let export: [String: Any] = [
            "app": "Lyttejeger",
            "versjon": AppConstants.appVersion,
            "eksportert": formatter.string(from: Date()),
            "abonnementer": subscriptions.map { sub in
                [
                    "podcastId": sub.podcastId,
                    "tittel": sub.title,
                    "forfatter": sub.author,
                    "feedUrl": sub.feedUrl,
                    "abonnertDato": formatter.string(from: sub.subscribedAt),
                ] as [String: Any]
            },
            "spillekø": queueItems.map { item in
                [
                    "episodeId": item.episodeId,
                    "tittel": item.title,
                    "podkast": item.podcastTitle,
                    "audioUrl": item.audioUrl,
                    "posisjon": item.position,
                ] as [String: Any]
            },
            "avspillingsposisjoner": positions.map { pos in
                [
                    "episodeId": pos.episodeId,
                    "posisjon": pos.position,
                    "varighet": pos.duration,
                    "fullført": pos.completed,
                    "oppdatert": formatter.string(from: pos.updatedAt),
                ] as [String: Any]
            },
            "innstillinger": [
                "visFortsettÅLytte": UserDefaults.standard.bool(forKey: "showLastPlayed"),
                "visNyttFraAbonnementer": UserDefaults.standard.bool(forKey: "showNewFromSubscriptions"),
            ] as [String: Any],
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("lyttejeger-data.json")
        try? jsonData.write(to: fileURL)

        exportURL = fileURL
        showExportSheet = true
    }

    // MARK: - Data Deletion

    private func deleteAllData() {
        try? modelContext.delete(model: Subscription.self)
        try? modelContext.delete(model: QueueItem.self)
        try? modelContext.delete(model: PlaybackPosition.self)
        try? modelContext.save()

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "lastPlayedInfo")
        UserDefaults.standard.removeObject(forKey: "showLastPlayed")
        UserDefaults.standard.removeObject(forKey: "showNewFromSubscriptions")

        // Clear URL caches
        URLCache.shared.removeAllCachedResponses()
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#if DEBUG
#Preview {
    OmLyttejegerView()
        .modelContainer(previewContainer)
}
#endif

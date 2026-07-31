import SwiftUI
import SwiftData

/// Single menu sheet opened from the tab bar. Replaces the previous
/// three-sheet chain (menu -> Innstillinger / Om Lyttejeger) with one
/// calm surface built from AppCardSection + AppMenuRow.
struct MenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @AppStorage(AppConstants.showLastPlayedKey) private var showLastPlayed = true
    @AppStorage(AppConstants.showNewFromSubscriptionsKey) private var showNewFromSubscriptions = true
    @State private var showExportConfirmation = false
    @State private var showDeleteConfirmation = false

    private let privacyURL = URL(string: "https://github.com/elzacka/lyttejeger-ios/blob/main/Personvern.md")!
    private let guideURL = URL(string: "https://github.com/elzacka/lyttejeger-ios/blob/main/Brukerveiledning.md")!

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Hero
                VStack(spacing: AppSpacing.sm) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)

                    Text("Lyttejeger")
                        .font(.pageTitle)
                        .foregroundStyle(Color.appForeground)

                    Text("Rolig og smart podkastspiller som lar deg lytte i fred")
                        .font(.caption2Text)
                        .foregroundStyle(Color.appMutedForeground)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                AppCardSection("Hjem-skjerm") {
                    toggleRow(
                        title: "Fortsett å lytte",
                        subtitle: "Vis uferdig episode",
                        isOn: $showLastPlayed
                    )
                    AppMenuRowDivider()
                    toggleRow(
                        title: "Nytt fra Mine podder",
                        subtitle: "Episoder fra siste 7 dager",
                        isOn: $showNewFromSubscriptions
                    )
                }

                AppCardSection("Dine data") {
                    AppMenuRow(
                        icon: "square.and.arrow.down",
                        label: "Eksporter som JSON",
                        action: { showExportConfirmation = true },
                        accessibilityHint: "Eksporterer alle data som JSON-fil"
                    )
                    AppMenuRowDivider()
                    AppMenuRow(
                        icon: "trash",
                        label: "Slett alle data",
                        iconColor: .appError,
                        labelColor: .appError,
                        action: { showDeleteConfirmation = true },
                        accessibilityHint: "Sletter alle lokalt lagrede data"
                    )
                }

                AppCardSection("Datakilder") {
                    AppMenuRow(
                        label: "Podcast Index API",
                        subtitle: "Åpen podkastdatabase"
                    )
                    AppMenuRowDivider()
                    AppMenuRow(
                        label: "github.com/sindrel/nrk-pod-feeds",
                        subtitle: "NRK-podkaster via åpne RSS-feeds"
                    )
                }

                AppCardSection("Om appen") {
                    AppMenuRow(
                        label: "Versjon",
                        accessibilityValue: AppConstants.appVersion,
                        trailing: { AppMenuRowValue(value: AppConstants.appVersion) }
                    )
                    AppMenuRowDivider()
                    AppMenuRow(
                        label: "Brukerveiledning",
                        action: { openURL(guideURL) },
                        accessibilityHint: "Åpner i nettleser",
                        trailing: { AppMenuRowExternal() }
                    )
                    AppMenuRowDivider()
                    AppMenuRow(
                        label: "Personvernerklæring",
                        action: { openURL(privacyURL) },
                        accessibilityHint: "Åpner i nettleser",
                        trailing: { AppMenuRowExternal() }
                    )
                }

                Spacer(minLength: AppSpacing.xxl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
        }
        .background(Color.appBackground)
        .alert("Eksporter data?", isPresented: $showExportConfirmation) {
            Button("Avbryt", role: .cancel) {}
            Button("Eksporter") {
                exportData()
            }
        } message: {
            Text("Eksporterer abonnementer, spillekø og avspillingsposisjoner som JSON-fil.")
        }
        .alert("Slett alle data?", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) {}
            Button("Slett", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("Dette sletter alle abonnementer, spillekøen og avspillingsposisjoner. Handlingen kan ikke angres.")
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
        .padding(.vertical, AppSpacing.sm)
        .frame(minHeight: AppSize.touchTarget)
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
                "visFortsettÅLytte": UserDefaults.standard.bool(forKey: AppConstants.showLastPlayedKey),
                "visNyttFraAbonnementer": UserDefaults.standard.bool(forKey: AppConstants.showNewFromSubscriptionsKey),
            ] as [String: Any],
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("lyttejeger-data.json")
        try? jsonData.write(to: fileURL, options: .completeFileProtection)

        // Present UIActivityViewController directly via UIKit
        // (wrapping in SwiftUI .sheet causes a blank white sheet on iOS 26)
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: fileURL)
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.keyWindow?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Data Deletion

    private func deleteAllData() {
        // Stop playback via ViewModel (cleans up sleep timer, tasks, and calls audioService.stop())
        playerVM.stop()

        try? modelContext.delete(model: Subscription.self)
        try? modelContext.delete(model: QueueItem.self)
        try? modelContext.delete(model: PlaybackPosition.self)
        try? modelContext.save()

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: AppConstants.lastPlayedInfoKey)
        UserDefaults.standard.removeObject(forKey: AppConstants.showLastPlayedKey)
        UserDefaults.standard.removeObject(forKey: AppConstants.showNewFromSubscriptionsKey)
        UserDefaults.standard.removeObject(forKey: AppConstants.podcastSpeedPrefsKey)

        // Clear URL caches
        URLCache.shared.removeAllCachedResponses()
        CachedAsyncImage.clearCache()

        // Clear in-memory service caches (awaited to ensure complete deletion)
        Task {
            await ChapterService.shared.clearCache()
            await TranscriptService.shared.clearCache()
            await PodcastIndexAPI.shared.clearCache()
            await NRKPodcastService.shared.clearCache()
        }
    }
}

#if DEBUG
#Preview {
    PreviewWrapper {
        MenuView()
    }
}
#endif

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    /// OPML has no system-declared type. The app declares `org.opml.opml`
    /// itself (UTImportedTypeDeclarations in project.yml), which is what this
    /// lookup resolves to, and what lets other apps offer "Åpne i Lyttejeger".
    /// `.xml` is accepted alongside it in the picker because several podcast
    /// apps export OPML with an .xml extension.
    static let opml = UTType(filenameExtension: "opml", conformingTo: .xml) ?? .xml
}

/// Root view of the menu tab. Built from AppCardSection + AppMenuRow, and
/// configured like the other three tab roots: full-bleed, own background,
/// hidden navigation bar, and its own PodcastRoute destination.
struct MenuView: View {
    /// A file handed to the app from outside, routed here by ContentView
    /// because import lives on this tab. Cleared once handled.
    @Binding var pendingImportURL: URL?

    init(pendingImportURL: Binding<URL?> = .constant(nil)) {
        self._pendingImportURL = pendingImportURL
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(AudioPlayerViewModel.self) private var playerVM
    // Needed so an import shows up immediately in Følgeliste and Kø
    @Environment(SubscriptionViewModel.self) private var subscriptionVM
    @Environment(QueueViewModel.self) private var queueVM
    @AppStorage(AppConstants.showLastPlayedKey) private var showLastPlayed = true
    @AppStorage(AppConstants.showNewFromSubscriptionsKey) private var showNewFromSubscriptions = true
    @AppStorage(AppConstants.keepEpisodesInQueueKey) private var keepEpisodesInQueue = false
    @State private var showExportConfirmation = false
    @State private var showOPMLExportConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showFileImporter = false
    /// Progress or result of the last import, shown under the card.
    @State private var importStatus: String?
    /// Whether `importStatus` reports a failure, so it can be styled as one.
    @State private var importStatusIsError = false
    @State private var isImporting = false

    private let privacyURL = URL(string: "https://github.com/elzacka/lyttejeger-ios/blob/main/Personvern.md")!
    private let guideURL = URL(string: "https://github.com/elzacka/lyttejeger-ios/blob/main/Brukerveiledning.md")!

    var body: some View {
        VStack(spacing: 0) {
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

                AppCardSection("Hjem") {
                    toggleRow("Fortsett", isOn: $showLastPlayed)
                    AppMenuRowDivider()
                    toggleRow("Nyeste", isOn: $showNewFromSubscriptions)
                }

                AppCardSection("Kø") {
                    toggleRow("Behold episoder i køen", isOn: $keepEpisodesInQueue)
                }

                AppCardSection("Dataene dine") {
                    AppMenuRow(
                        icon: "square.and.arrow.up",
                        label: "Importer",
                        isEnabled: !isImporting,
                        action: { showFileImporter = true },
                        accessibilityHint: "Velg en OPML- eller JSON-fil å importere"
                    )
                    AppMenuRowDivider()
                    AppMenuRow(
                        icon: "square.and.arrow.down",
                        label: "Eksporter følgelisten din",
                        action: { showOPMLExportConfirmation = true },
                        accessibilityHint: "Eksporterer følgelisten din som OPML-fil"
                    )
                    AppMenuRowDivider()
                    AppMenuRow(
                        icon: "square.and.arrow.down",
                        label: "Eksporter alle data",
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

                if let importStatus {
                    Text(importStatus)
                        .font(.caption2Text)
                        .foregroundStyle(importStatusIsError ? Color.appError : Color.appMutedForeground)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                AppCardSection("Datakilder") {
                    AppMenuRow(label: "Podcast Index API")
                    AppMenuRowDivider()
                    AppMenuRow(label: "github.com/sindrel/nrk-pod-feeds")
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
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppConstants.playerBottomPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: PodcastRoute.self) { route in
            PodcastDetailView(podcast: route.podcast, focusEpisodeId: route.focusEpisodeId)
        }
        .onChange(of: pendingImportURL) { _, url in
            guard let url else { return }
            pendingImportURL = nil
            Task { await handleImport(url) }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.opml, .json, .xml],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await handleImport(url) }
        }
        .alert("Eksporter data?", isPresented: $showExportConfirmation) {
            Button("Avbryt", role: .cancel) {}
            Button("Eksporter") {
                exportData()
            }
        } message: {
            Text("Eksporterer følgelisten, køen og hvor langt du har hørt, som JSON-fil.")
        }
        .alert("Eksporter følgelisten?", isPresented: $showOPMLExportConfirmation) {
            Button("Avbryt", role: .cancel) {}
            Button("Eksporter") {
                exportOPML()
            }
        } message: {
            Text("Lager en OPML-fil med podkastene du følger. De fleste podkastapper kan lese den. Køen og hvor langt du har hørt er ikke med.")
        }
        .alert("Slett alle data?", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) {}
            Button("Slett", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("Dette sletter følgelisten, køen og hvor langt du har hørt. Handlingen kan ikke angres.")
        }
    }

    /// Deliberately mirrors `AppMenuRow`'s anatomy — same font, same padding,
    /// same minimum height — so a toggle row and a tappable row are the same
    /// height and the screen reads as one rhythm. Both land on the 44pt
    /// minimum: neither a switch nor a single label is tall enough to exceed
    /// it once the subtitles are gone.
    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.smallText)
                .foregroundStyle(Color.appForeground)
        }
        .tint(Color.appAccent)
        .padding(.vertical, AppSpacing.sm)
        .frame(minHeight: AppSize.touchTarget)
    }

    // MARK: - Data Export

    private func exportData() {
        let context = modelContext
        do {
            let subscriptions = try context.fetch(FetchDescriptor<Subscription>())
            let queueItems = try context.fetch(FetchDescriptor<QueueItem>(sortBy: [SortDescriptor(\.position)]))
            let positions = try context.fetch(FetchDescriptor<PlaybackPosition>())
            let data = try DataTransferService.makeJSONExport(
                subscriptions: subscriptions,
                queueItems: queueItems,
                positions: positions,
                exportedAt: Date()
            )
            share(data, filename: "lyttejeger-data.json")
        } catch {
            importStatus = "Kunne ikke eksportere dataene. Prøv igjen."
            importStatusIsError = true
        }
    }

    private func exportOPML() {
        do {
            let subscriptions = try modelContext.fetch(
                FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.title)])
            )
            guard !subscriptions.isEmpty else {
                importStatus = "Du følger ingen podkaster ennå, så det er ingenting å eksportere."
            importStatusIsError = false
                return
            }
            let data = DataTransferService.makeOPMLExport(subscriptions: subscriptions, exportedAt: Date())
            share(data, filename: "lyttejeger-abonnementer.opml")
        } catch {
            importStatus = "Kunne ikke eksportere dataene. Prøv igjen."
            importStatusIsError = true
        }
    }

    /// Writes to a temporary file and hands it to the share sheet.
    ///
    /// UIActivityViewController is presented through UIKit directly: wrapping
    /// it in a SwiftUI .sheet renders a blank white sheet on iOS 26.
    private func share(_ data: Data, filename: String) {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .completeFileProtection)
        } catch {
            importStatus = "Kunne ikke lagre filen. Prøv igjen."
            importStatusIsError = true
            return
        }

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

    // MARK: - Data Import

    private func handleImport(_ url: URL) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }

        guard let data = await readPickedFile(url) else {
            importStatus = "Kunne ikke lese filen."
            importStatusIsError = true
            return
        }

        guard let format = DataTransferService.detectFormat(url: url, data: data) else {
            importStatus = "Filformatet er ikke støttet. Velg en OPML- eller JSON-fil."
            importStatusIsError = true
            return
        }

        do {
            let summary: ImportSummary
            switch format {
            case .json:
                importStatus = "Importerer…"
            importStatusIsError = false
                summary = try DataTransferService.importJSON(data, into: modelContext)
            case .opml:
                summary = try await DataTransferService.importOPML(
                    data,
                    into: modelContext,
                    api: PodcastIndexAPI.shared
                ) { done, total in
                    importStatus = "Henter podkast \(done) av \(total)…"
                }
            }
            importStatus = message(for: summary)
            importStatusIsError = false
            UIAccessibility.post(notification: .announcement, argument: importStatus)
            subscriptionVM.fetchSubscriptions()
            queueVM.fetchQueue()
            removeIfInbox(url)
        } catch {
            importStatus = (error as? LocalizedError)?.errorDescription ?? "Importen feilet."
            importStatusIsError = true
        }
    }

    /// Reads a file the user picked or another app handed over.
    ///
    /// Off the main actor, and through NSFileCoordinator: the file can live in
    /// iCloud Drive or another app's provider, where a plain synchronous read
    /// either blocks the UI while the file downloads or returns nothing.
    private func readPickedFile(_ url: URL) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            // Files chosen through the picker live outside the sandbox
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            var coordinatorError: NSError?
            var data: Data?
            NSFileCoordinator().coordinate(
                readingItemAt: url,
                options: .withoutChanges,
                error: &coordinatorError
            ) { readableURL in
                data = try? Data(contentsOf: readableURL)
            }
            return data
        }.value
    }

    /// Deletes the copy iOS leaves in Documents/Inbox when another app hands
    /// us a file. Only ever touches that directory, and only after the import
    /// succeeded, so a failed import leaves the file for a retry.
    private func removeIfInbox(_ url: URL) {
        let inbox = URL.documentsDirectory.appendingPathComponent("Inbox")
        guard url.standardizedFileURL.path.hasPrefix(inbox.standardizedFileURL.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Plain-language result, so the user knows what changed.
    private func message(for summary: ImportSummary) -> String {
        if summary.isEmpty && summary.skippedSubscriptions > 0 {
            return "Alt i filen fantes fra før. Ingenting ble lagt til."
        }
        if summary.isEmpty {
            return "Fant ingenting å importere i filen."
        }

        var parts: [String] = []
        if summary.addedSubscriptions > 0 {
            parts.append(summary.addedSubscriptions == 1 ? "1 podkast" : "\(summary.addedSubscriptions) podkaster")
        }
        if summary.addedQueueItems > 0 {
            parts.append(summary.addedQueueItems == 1 ? "1 episode i køen" : "\(summary.addedQueueItems) episoder i køen")
        }
        if summary.addedPositions > 0 {
            parts.append(summary.addedPositions == 1 ? "1 avspillingsposisjon" : "\(summary.addedPositions) avspillingsposisjoner")
        }

        var text = "La til " + parts.joined(separator: ", ") + "."
        if summary.skippedSubscriptions > 0 {
            text += " \(summary.skippedSubscriptions) fantes fra før."
        }
        if summary.failedSubscriptions > 0 {
            text += " \(summary.failedSubscriptions) kunne ikke hentes."
        }
        return text
    }

    // MARK: - Data Deletion

    private func deleteAllData() {
        // Stop playback via ViewModel (cleans up sleep timer, tasks, and calls audioService.stop())
        playerVM.stop()

        do {
            try DataTransferService.deleteAllUserData(in: modelContext)
        } catch {
            importStatus = "Kunne ikke slette alle data. Prøv igjen."
            importStatusIsError = true
            UIAccessibility.post(notification: .announcement, argument: importStatus)
            return
        }

        // The list views hold their own fetched copies, so refresh them or the
        // deleted items stay on screen until the next relaunch.
        subscriptionVM.fetchSubscriptions()
        queueVM.fetchQueue()
        importStatus = "Alle data er slettet."
            importStatusIsError = false
        UIAccessibility.post(notification: .announcement, argument: importStatus)

        // Clear UserDefaults
        DataTransferService.deleteAllUserDefaults()

        // Clear URL caches
        URLCache.shared.removeAllCachedResponses()
        CachedAsyncImage.clearCache()

        // Clear in-memory service caches (awaited to ensure complete deletion)
        Task {
            await ChapterService.shared.clearCache()
            await TranscriptService.shared.clearCache()
            await PodcastIndexAPI.shared.clearCache()
            await NRKPodcastService.shared.clearCache()
            await RSSFeedService.shared.clearCache()
        }
    }
}

#if DEBUG
#Preview {
    PreviewWrapper {
        NavigationStack {
            MenuView()
        }
    }
}
#endif

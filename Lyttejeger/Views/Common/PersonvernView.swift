import SwiftUI
import SwiftData

struct PersonvernView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Hero
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(Color.appAccent)

                        Text("Dine data forblir\npå din enhet")
                            .font(.sectionTitle)
                            .foregroundStyle(Color.appForeground)
                            .multilineTextAlignment(.center)

                        Text("Ingen sporing, ingen kontoer, ingen sky.")
                            .font(.smallText)
                            .foregroundStyle(Color.appMutedForeground)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)

                    // Cards
                    card {
                        cardHeader("Lagres lokalt", icon: "internaldrive")

                        cardRow("Avspillingsposisjoner")
                        cardRow("Spillekø")
                        cardRow("Abonnementer")

                        Text("Slettes automatisk med appen.")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appMutedForeground)
                            .padding(.top, AppSpacing.xs)
                    }

                    card {
                        cardHeader("Nettverkstrafikk", icon: "arrow.up.arrow.down")

                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            trafficRow(
                                service: "Podcast Index",
                                detail: "Søketekst og IP-adresse ved søk"
                            )
                            trafficRow(
                                service: "NRK-katalog (GitHub)",
                                detail: "Henter podkastkatalog, ingen brukerdata sendes"
                            )
                            trafficRow(
                                service: "Podkastverter",
                                detail: "Lyd og bilder hentes direkte fra podkastens egen server"
                            )
                        }

                        Text("All nettverkstrafikk går direkte fra din enhet. Ingen data sendes via våre servere.")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appMutedForeground)
                            .padding(.top, AppSpacing.xs)
                    }

                    card {
                        cardHeader("Appen bruker ikke", icon: "xmark.shield")

                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                negativeRow("Analyse/sporing")
                                negativeRow("Annonser")
                                negativeRow("Skytjenester")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                negativeRow("Kontoer")
                                negativeRow("Cookies")
                                negativeRow("Tredjepartskode")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Data management
                    card {
                        cardHeader("Dine data", icon: "square.and.arrow.up")

                        Button {
                            exportData()
                        } label: {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "doc.text")
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

                    // Footer
                    VStack(spacing: AppSpacing.xs) {
                        Text("Lyttejeger \(AppConstants.appVersion)")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appBorder)
                        Text("Åpen kildekode")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appBorder)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xxxl)
                }
                .padding(.horizontal, AppSpacing.lg)
            }
            .background(Color.appBackground)
            .navigationTitle("Personvern")
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

    private func cardHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.appAccent)
            Text(title)
                .font(.caption2Text)
                .foregroundStyle(Color.appMutedForeground)
                .textCase(.uppercase)
        }
    }

    private func cardRow(_ text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(Color.appAccent)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.smallText)
                .foregroundStyle(Color.appForeground)
        }
    }

    private func trafficRow(service: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(service)
                .font(.smallText)
                .foregroundStyle(Color.appForeground)
            Text(detail)
                .font(.caption2Text)
                .foregroundStyle(Color.appMutedForeground)
        }
    }

    private func negativeRow(_ text: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.appBorder)
            Text(text)
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
    PersonvernView()
        .modelContainer(previewContainer)
}
#endif

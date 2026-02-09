#if DEBUG
import SwiftUI
import SwiftData

// MARK: - Preview Containers

@MainActor
let previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: QueueItem.self, Subscription.self, PlaybackPosition.self,
        configurations: config
    )
    seedPreviewData(in: container.mainContext)
    return container
}()

@MainActor
private func seedPreviewData(in context: ModelContext) {
    for (index, ep) in Episode.previewList.enumerated() {
        let item = QueueItem(
            episodeId: ep.id,
            podcastId: ep.podcastId,
            title: ep.title,
            episodeDescription: ep.description,
            podcastTitle: ep.podcastId == "920666" ? "Aftenpodden" : "Kriminelt",
            audioUrl: ep.audioUrl,
            podcastImage: nil,
            duration: ep.duration,
            position: index
        )
        context.insert(item)
    }

    for podcast in Podcast.previewList {
        let sub = Subscription(
            podcastId: podcast.id,
            title: podcast.title,
            author: podcast.author,
            imageUrl: podcast.imageUrl,
            feedUrl: podcast.feedUrl
        )
        context.insert(sub)
    }

    try? context.save()
}

// MARK: - Preview Wrapper

/// Injiserer alle environment-objekter og SwiftData-container for previews.
/// - `player`: Konfigurer spillertilstand (.playing / .paused)
/// - `searchResults`: Vis forhåndsutfylte søkeresultater
/// - `seeded`: Kall setup() på ViewModels slik at SwiftData-data lastes inn
struct PreviewWrapper<Content: View>: View {
    let playerConfig: PlayerPreviewConfig?
    let withSearchResults: Bool
    let withSeededData: Bool
    @ViewBuilder let content: () -> Content

    enum PlayerPreviewConfig {
        case playing
        case paused
    }

    init(
        player: PlayerPreviewConfig? = nil,
        searchResults: Bool = false,
        seeded: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.playerConfig = player
        self.withSearchResults = searchResults
        self.withSeededData = seeded
        self.content = content
    }

    @State private var searchVM = SearchViewModel()
    @State private var queueVM = QueueViewModel()
    @State private var subscriptionVM = SubscriptionViewModel()
    @State private var playerVM = AudioPlayerViewModel()
    @State private var progressVM = PlaybackProgressViewModel()

    var body: some View {
        content()
            .environment(searchVM)
            .environment(queueVM)
            .environment(subscriptionVM)
            .environment(playerVM)
            .environment(progressVM)
            .modelContainer(previewContainer)
            .preferredColorScheme(.light)
            .task {
                if withSeededData {
                    let context = previewContainer.mainContext
                    queueVM.setup(context)
                    subscriptionVM.setup(context)
                    playerVM.setup(context)
                    progressVM.setup(context)
                }

                if let playerConfig {
                    configurePreviewPlayer(
                        on: playerVM,
                        isPlaying: playerConfig == .playing
                    )
                }

                if withSearchResults {
                    searchVM.filters.query = "podkast"
                    searchVM.podcasts = Podcast.previewList
                    searchVM.episodes = EpisodeWithPodcast.previewList
                }
            }
    }
}

// MARK: - Player Preview Helper

@MainActor
func configurePreviewPlayer(
    on playerVM: AudioPlayerViewModel,
    episode: Episode = .preview,
    podcastTitle: String = "Aftenpodden",
    isPlaying: Bool = true,
    currentTime: TimeInterval = 645,
    duration: TimeInterval = 2700
) {
    let service = AudioService.shared
    service.currentEpisode = episode
    service.currentPodcastTitle = podcastTitle
    service.currentPodcastImage = ""
    service.isPlaying = isPlaying
    service.currentTime = currentTime
    service.duration = duration
    playerVM.chapters = Chapter.previewList
    playerVM.transcript = .preview
}

// MARK: - Sample Data: Podcast

extension Podcast {
    static let preview = Podcast(
        id: "920666",
        title: "Aftenpodden",
        author: "Aftenposten",
        description: "Aftenpostens daglige podkast om nyheter, politikk og samfunn. Hver dag tar vi pulsen på det som skjer i Norge og verden.",
        imageUrl: "",
        feedUrl: "https://example.com/feed.xml",
        categories: ["News", "Society"],
        language: "no",
        episodeCount: 342,
        lastUpdated: "2026-02-07T10:00:00Z",
        rating: 4.5,
        explicit: false
    )

    static let previewList: [Podcast] = [
        .preview,
        Podcast(
            id: "920667",
            title: "Kriminelt",
            author: "NRK",
            description: "Norges mest populære kriminalpodkast.",
            imageUrl: "",
            feedUrl: "https://example.com/feed2.xml",
            categories: ["True Crime"],
            language: "no",
            episodeCount: 87,
            lastUpdated: "2026-02-06T08:00:00Z",
            rating: 4.8,
            explicit: false
        ),
        Podcast(
            id: "920668",
            title: "Oppdatert",
            author: "NRK",
            description: "NRKs nyhetspodkast som holder deg oppdatert på det viktigste.",
            imageUrl: "",
            feedUrl: "https://example.com/feed3.xml",
            categories: ["News", "Daily News"],
            language: "no",
            episodeCount: 1200,
            lastUpdated: "2026-02-07T16:00:00Z",
            rating: 4.2,
            explicit: false
        ),
        Podcast(
            id: "920669",
            title: "Hele historien",
            author: "VG",
            description: "Dybdejournalistikk i podkastformat.",
            imageUrl: "",
            feedUrl: "https://example.com/feed4.xml",
            categories: ["Society", "Documentary"],
            language: "no",
            episodeCount: 56,
            lastUpdated: "2026-01-20T12:00:00Z",
            rating: 4.6,
            explicit: false
        ),
    ]
}

// MARK: - Sample Data: Episode

extension Episode {
    static let preview = Episode(
        id: "ep-001",
        podcastId: "920666",
        title: "Fredagssamtalen: Vinter i Oslo",
        description: "En samtale om livet i Oslo midt i vinteren. Vi snakker om kulde, mørketid og hvordan man holder humøret oppe.",
        audioUrl: "https://example.com/episode.mp3",
        duration: 2700,
        publishedAt: "2026-02-07T08:00:00Z",
        imageUrl: nil,
        transcriptUrl: "https://example.com/transcript.vtt",
        chaptersUrl: "https://example.com/chapters.json",
        season: 3,
        episode: 42
    )

    static let previewList: [Episode] = [
        .preview,
        Episode(
            id: "ep-002",
            podcastId: "920666",
            title: "Mandagens nyheter",
            description: "En oppsummering av helgens viktigste hendelser og hva som venter oss denne uken.",
            audioUrl: "https://example.com/ep2.mp3",
            duration: 1800,
            publishedAt: "2026-02-03T07:00:00Z",
            season: 3,
            episode: 41
        ),
        Episode(
            id: "ep-003",
            podcastId: "920666",
            title: "Intervju: Klimaforskeren",
            description: "Vi møter en av Norges fremste klimaforskere for å snakke om hva som venter oss.",
            audioUrl: "https://example.com/ep3.mp3",
            duration: 3600,
            publishedAt: "2026-01-31T08:00:00Z",
            transcriptUrl: "https://example.com/transcript3.vtt",
            season: 3,
            episode: 40
        ),
        Episode(
            id: "ep-004",
            podcastId: "920667",
            title: "Forsvinningen i Nordmarka",
            description: "En mystisk forsvinning som fortsatt er uløst etter 30 år.",
            audioUrl: "https://example.com/ep4.mp3",
            duration: 4200,
            publishedAt: "2026-01-28T10:00:00Z",
            chaptersUrl: "https://example.com/chapters4.json",
            season: 2,
            episode: 8
        ),
        Episode(
            id: "ep-005",
            podcastId: "920667",
            title: "Den siste samtalen",
            description: "Hva skjedde de siste timene før den brutale hendelsen?",
            audioUrl: "https://example.com/ep5.mp3",
            duration: 3000,
            publishedAt: "2026-01-21T10:00:00Z",
            season: 2,
            episode: 7
        ),
    ]
}

// MARK: - Sample Data: EpisodeWithPodcast

extension EpisodeWithPodcast {
    static let preview = EpisodeWithPodcast(
        episode: .preview,
        podcast: .preview,
        podcastTitle: "Aftenpodden",
        podcastAuthor: "Aftenposten",
        podcastImage: "",
        feedLanguage: "no"
    )

    static let previewList: [EpisodeWithPodcast] = Episode.previewList.map { ep in
        let podcast = Podcast.previewList.first { $0.id == ep.podcastId } ?? .preview
        return EpisodeWithPodcast(
            episode: ep,
            podcast: podcast,
            podcastTitle: podcast.title,
            podcastAuthor: podcast.author,
            podcastImage: podcast.imageUrl,
            feedLanguage: podcast.language
        )
    }
}

// MARK: - Sample Data: Chapter

extension Chapter {
    static let previewList: [Chapter] = [
        Chapter(startTime: 0, title: "Introduksjon", endTime: 120),
        Chapter(startTime: 120, title: "Dagens tema", endTime: 600),
        Chapter(startTime: 600, title: "Gjestens perspektiv", endTime: 1200),
        Chapter(startTime: 1200, title: "Oppsummering", endTime: 1500),
    ]
}

// MARK: - Sample Data: Transcript

extension Transcript {
    static let preview = Transcript(
        segments: [
            TranscriptSegment(startTime: 0, endTime: 15, text: "Velkommen til Aftenpodden. I dag skal vi snakke om vinteren i Oslo.", speaker: "Programleder"),
            TranscriptSegment(startTime: 15, endTime: 35, text: "Det har vært en uvanlig kald vinter i år, med temperaturer ned mot minus tjue grader.", speaker: "Programleder"),
            TranscriptSegment(startTime: 35, endTime: 60, text: "Absolutt. Og det merkes godt på folk. Mange sliter med mørketiden.", speaker: "Gjest"),
            TranscriptSegment(startTime: 60, endTime: 90, text: "Hva er ditt beste tips for å holde humøret oppe i mørketiden?", speaker: "Programleder"),
            TranscriptSegment(startTime: 90, endTime: 120, text: "Jeg tror det viktigste er å komme seg ut i dagslyset, selv om det bare er en kort tur.", speaker: "Gjest"),
            TranscriptSegment(startTime: 120, endTime: 150, text: "La oss gå videre til dagens tema. Vi har invitert en ekspert på vinterdepresjon.", speaker: "Programleder"),
            TranscriptSegment(startTime: 150, endTime: 180, text: "Takk for at jeg fikk komme. Dette er et tema som opptar mange nordmenn.", speaker: "Ekspert"),
            TranscriptSegment(startTime: 180, endTime: 210, text: "Forskning viser at opptil 15 prosent av befolkningen opplever sesongavhengige symptomer.", speaker: "Ekspert"),
        ],
        language: "no"
    )
}
#endif

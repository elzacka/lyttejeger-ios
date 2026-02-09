# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Lyttejeger is a native iOS podcast player written in SwiftUI. The app uses a calm beige/teal retro design with DM Mono typography, light mode only. All UI text is in Norwegian.

- **Bundle ID:** `no.lene.lyttejeger`
- **Developer Team:** `8NW62A7PRA` (Tazk)
- **Swift 6.2**, iOS 26.2, Xcode 26.2
- **Strict concurrency:** `SWIFT_STRICT_CONCURRENCY: complete`
- **Portrait only**, iPhone only, zero third-party dependencies
- **Data sources:** Podcast Index API (primary) + NRK podcast feeds (Norwegian public radio)

## Build Commands

The project uses `xcodegen` to generate the `.xcodeproj` from `project.yml`. Always regenerate after adding/removing files.

```bash
# Regenerate Xcode project (required after adding/removing Swift files)
cd /Users/lene/dev/lyttejeger-ios && xcodegen generate

# Build (xcode-select points to CommandLineTools, so DEVELOPER_DIR override is required)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && xcodebuild \
  -project Lyttejeger.xcodeproj -scheme Lyttejeger \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build

# Generate app icons from Headphones.png source (requires macOS AppKit)
swift scripts/generate-icons.swift
```

**Info.plist changes** (e.g. UILaunchScreen) require deleting the app from the simulator before rebuilding:
`xcrun simctl uninstall booted no.lene.lyttejeger`

## Architecture

### Data Flow

`LyttejegerApp` creates a SwiftData `ModelContainer` and shows a `SplashScreenView` overlay on launch. `ContentView` owns all five `@State` ViewModels, injecting them via `.environment()`. ViewModels that need persistence receive `ModelContext` via `setup(modelContext)` called in `.onAppear`.

```
LyttejegerApp (.modelContainer, SplashScreenView overlay)
  └─ ContentView (@State VMs, .environment(), custom tab bar)
       ├─ Tab 0 "Søk" → HomeView → PodcastDetailView → EpisodeRow
       ├─ Tab 1 "Mine podder" → MyPodsView → PodcastDetailView
       └─ Tab 2 "Kø" → QueueView
       └─ AudioPlayerBar → AudioPlayerSheet (fullScreenCover)
```

Tab bar is a **custom SwiftUI HStack** (not system TabView). iOS 26's floating TabView ignores UIKit appearance customization, so we built our own: icon-only, all teal, dot indicator for selected tab. Tab content uses ZStack with opacity-based switching to preserve NavigationStack state.

### Layers

| Layer | Pattern | Examples |
|-------|---------|----------|
| **Models** | Plain structs (`Sendable`) | `Podcast`, `Episode`, `Chapter`, `EpisodeWithPodcast` |
| **Persistence** | SwiftData `@Model` classes | `QueueItem`, `Subscription`, `PlaybackPosition` |
| **Services** | Actors (thread-safe singletons) | `PodcastIndexAPI.shared`, `NRKPodcastService.shared`, `ChapterService.shared`, `TranscriptService.shared` |
| **Audio** | `@Observable @MainActor` singleton | `AudioService.shared` (AVPlayer, MediaPlayer, remote commands) |
| **ViewModels** | `@Observable @MainActor` classes | `SearchViewModel`, `QueueViewModel`, `SubscriptionViewModel`, `AudioPlayerViewModel`, `PlaybackProgressViewModel` |
| **Views** | SwiftUI with `@Environment` injection | All views read VMs from environment |
| **Transform** | Stateless enum | `PodcastTransform` (API types → domain types, HTML→text) |

### Podcast Index API

- SHA1 auth via CryptoKit, 1 req/sec rate limit, 5-min cache TTL
- Certificate pinning via `APIPinningDelegate` in `PodcastIndexAPI.swift`
- API keys XOR-obfuscated in `Config/Secrets.swift` (gitignored)

### NRK Podcast Integration

NRK (Norwegian Broadcasting) podcasts use a separate data source since they're poorly indexed in Podcast Index:

- **Catalog:** `podcasts.json` from `sindrel/nrk-pod-feeds` GitHub repo, cached 24h
- **RSS feeds:** `https://sindrel.github.io/nrk-pod-feeds/rss/{slug}.xml`, cached 30min
- **ID convention:** `"nrk:{slug}"` (e.g., `"nrk:abels_taarn"`) — trivially detectable via `id.hasPrefix("nrk:")`
- **`Podcast.isNRKFeed`** and **`Podcast.nrkSlug`** computed properties for routing
- **Title cleaning:** Catalog titles have "De N siste fra " prefix that gets stripped via regex
- **`PodcastDetailView`** auto-detects NRK podcasts via `findNRKSlug()` title matching — routes episode loading to NRK RSS even when the podcast was found via Podcast Index (better durations)
- **`SearchViewModel`** merges NRK results after Podcast Index results with title-based deduplication

### Key Patterns

- **`AudioPlayerViewModel`** proxies `AudioService.shared` via computed properties. To set player state for previews, configure `AudioService.shared` directly (see `configurePreviewPlayer()` in PreviewHelpers.swift).
- **`AudioService.play()`** waits for `.readyToPlay` before setting playback rate. Never set `player?.rate` before the status observer fires.
- **`PodcastTransform`** maps API response types (`PodcastIndexFeed`, `PodcastIndexEpisode`) to domain types (`Podcast`, `Episode`). HTML descriptions are stripped via pre-compiled regex.
- **`QueueItem.toEpisode()`** converts SwiftData queue items back to `Episode` structs.
- **`EpisodeContextMenu`** (ViewModifier) provides shared context menu for episode views (Play, Play Next, Add to Queue).
- **`CachedAsyncImage`** wraps `AsyncImage` with in-memory `NSCache` and disk caching via `FileManager`. Placeholder uses headphones icon.
- **Expandable descriptions** use `.lineLimit(isExpanded ? nil : N)` with `.onTapGesture` and a "Vis mer"/"Vis mindre" text link as affordance.
- **Previews** use `PreviewWrapper` which injects all environment objects and SwiftData container. Options: `player: .playing/.paused`, `searchResults: true`, `seeded: true`.
- **`PodcastDetailView`** detects Xcode previews via `ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"]` to skip API calls.
- **SwiftData model access in Tasks:** Always capture values (e.g., `let savedPosition = saved.position`) before passing to async Tasks — SwiftData models must not cross actor boundaries.

## Gotchas

- `MPNowPlayingInfoCenter.default` is a method in iOS 26 — use `.default()` not `.default`
- iOS 26 system `TabView` ignores `UITabBarAppearance` and `UITabBarItemAppearance` — use custom SwiftUI tab bar instead
- SwiftData `@Model` classes need explicit `init()` (no memberwise init)
- `#Predicate` requires variable name capture: `let episodeId = episode.id` before use in predicate
- `nonisolated(unsafe)` is needed for static `ISO8601DateFormatter` instances due to strict concurrency
- `SecTrustCopyCertificateChain` returns `CFArray` — cast to `[SecCertificate]` before iterating
- `Config/Secrets.swift` is gitignored — keys are XOR-obfuscated, decoded at runtime via computed properties
- `.swipeActions` only works on `List` rows, not `LazyVStack` items
- NRK catalog repo uses `master` branch (not `main`) — URLs must reference `master`

## Design System

- **Colors:** `Color.appBackground` (#F4F1EA), `.appAccent` (#1A5F7A), `.appForeground` (#2C2C2C), `.appMutedForeground` (#4A4A4A), `.appBorder` (#D4D0C6), `.appCard` (white), `.appError` (#9B2915), `.appSuccess` (#3D6649)
- **Typography:** All `Font` extensions use DM Mono with Dynamic Type (`relativeTo:`). Key styles: `.pageTitle`, `.sectionTitle`, `.cardTitle`, `.bodyText`, `.smallText`, `.caption2Text`, `.buttonText`
- **Spacing:** `AppSpacing` enum (xs=4, sm=8, md=12, lg=16, xl=24, xxl=32, xxxl=48)
- **Sizes:** `AppSize.touchTarget` = 44pt (WCAG 2.2 AA minimum), `.artworkSmall` = 56, `.artworkMedium` = 120, `.artworkLarge` = 280, `.miniPlayerHeight` = 80
- **Radii:** `AppRadius` enum (sm=4, md=8, lg=12)
- **Animations:** Always check `UIAccessibility.isReduceMotionEnabled` before animating
- **Icons:** App identity uses teal metallic headphones (generated from `Headphones.png`). SF Symbol `headphones` used for empty states and image placeholders. Play buttons use `play.circle.fill` at 32pt consistently.
- **Now-playing state:** Background opacity 0.08, border opacity 0.4 with 1.5pt width, teal title color
- **AudioPlayerBar:** Solid `Color.appCard` background with 1pt top border line

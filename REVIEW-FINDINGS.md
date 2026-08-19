# REVIEW-FINDINGS

Open findings from code reviews. Check this file before every review to avoid rediscovering known items. Full detail for the 18 Aug 2026 assessment lives in the report delivered with it; IDs match.

Last full assessment: 18 August 2026 (working tree at `eb45416` + uncommitted schema/import/export work). 72 findings: 1 P1, 18 P2, 53 P3. All adversarially verified.

Fix round 18 August 2026: closed LYT-01, LYT-02, LYT-04, LYT-05, LYT-08, LYT-11, LYT-12, LYT-13, LYT-16, LYT-18, LYT-59; partially addressed LYT-17 (mocks exist) and LYT-61 (deterministic UI tests); added LYT-73.

UI design review 18 August 2026 (visual hierarchy, typography scaling, touch targets, native navigation, interactive states): 43 fixes applied across contrast, Dynamic Type layout, tap targets, navigation, screen states and press feedback. Also closed LYT-07, LYT-14, LYT-15, LYT-37, LYT-38, LYT-50, LYT-51, LYT-54, LYT-55 from this tracker.

Player scrubber 18 August 2026: dragging the progress slider froze the position display while audio kept playing. Root cause was the scroll view added to the player that day; SwiftUI's end-of-drag callback is not delivered when another gesture recogniser takes the touch. The scroll view is now used only at accessibility sizes, and PlayerControls no longer depends on that callback — the drag is committed by a watchdog. Instrumented logging confirmed the callback can be absent entirely.

Documentation pass 18 August 2026: README, Brukerveiledning, Personvern, SECURITY, CLAUDE.md and the App Store checklist brought up to the current state; closed LYT-63, LYT-64, LYT-68.

## P1

- [x] **LYT-01** `Lyttejeger/Services/BackgroundRefreshService.swift:7` — BGTask completion guard is a static lock, so setTaskCompleted is never called on the second and later refreshes in the same process (fixed 18 Aug 2026: lock made local to handleRefresh)

## P2

- [x] **LYT-02** `Lyttejeger/Services/DataTransferService.swift:96` — JSON "full backup" drops most QueueItem fields, so a restored queue is permanently degraded (fixed 18 Aug 2026: all QueueItem fields exported with Norwegian keys, tolerant import keeps legacy backups working; round-trip test added)
- [ ] **LYT-03** `Lyttejeger/Services/DataTransferService.swift:294` — OPML import fallback creates "feed:" subscriptions that no code path in the app can ever load
- [x] **LYT-04** `Lyttejeger/Views/Common/MenuView.swift:340` — deleteAllData leaves deleted items visible in Kø and Mine podder, and swallows delete/save failures (fixed 18 Aug 2026: deletes moved to DataTransferService.deleteAllUserData, failures surfaced, VMs refreshed on success)
- [x] **LYT-05** `Lyttejeger/Views/Common/MenuView.swift:209` — Export path swallows every error — a fetch or write failure silently produces an empty or missing backup (fixed 18 Aug 2026: export and share paths surface failure via importStatus instead of returning silently)
- [ ] **LYT-06** `Lyttejeger/Utilities/RateLimiter.swift:24` — Cancelled searches permanently consume rate-limiter slots, delaying the next real search
- [x] **LYT-07** `Lyttejeger/ViewModels/SearchViewModel.swift:144` — Clearing the search query after a failed search leaves the error screen stuck (fixed 18 Aug 2026: error cleared on the empty-query path, plus a Prøv igjen control on the search error state)
- [x] **LYT-08** `Lyttejeger/ViewModels/AudioPlayerViewModel.swift:78` — Playback load failure is completely silent — hasError and isLoading are exposed but no view reads them (fixed 18 Aug 2026: AudioPlayerBar shows loading/error states on the play button, AudioPlayerSheet shows 'Kunne ikke spille av episoden.' with Prøv igjen)
- [ ] **LYT-09** `Lyttejeger/Services/ChapterService.swift:20` — Feed-controlled chapter/transcript URLs downloaded fully into memory without a size cap
- [ ] **LYT-10** `Lyttejeger/Services/PodcastIndexAPI.swift:139` — Default cookie handling contradicts the privacy policy's no-cookies claim and survives 'Slett alle data'
- [x] **LYT-11** `Lyttejeger/ViewModels/SearchViewModel+PodcastSearch.swift:90` — NRK results bypass the language filter (and category/date narrowing) in both search paths (fixed 18 Aug 2026: NRK matches run through filterByLanguage/filterByCategory, local filters applied after merge, episode strategy gated)
- [x] **LYT-12** `Lyttejeger/ViewModels/SearchViewModel+Browse.swift:98` — browseEpisodes builds Dictionary(uniqueKeysWithValues:) from an un-deduplicated API response and traps on a duplicate feed id (fixed 18 Aug 2026: seen-id dedupe before the dictionary)
- [x] **LYT-13** `Lyttejeger/Views/Player/PlayerControls.swift:84` — 44pt touch-target frames applied outside Button do not enlarge the tap area (fixed 18 Aug 2026: 44pt frames moved inside Button labels with contentShape across player views, panels, EpisodeCard, HomeView and QueueView)
- [x] **LYT-14** `Lyttejeger/Views/Library/QueueView.swift:78` — Color.appBorder used as text color fails contrast at 1.6:1 (fixed 18 Aug 2026: appBorder replaced with appMutedForeground at every text and meaningful-icon site)
- [x] **LYT-15** `Lyttejeger/Views/Player/AudioPlayerBar.swift:97` — Fixed-height mini player and tab bar clip text at accessibility Dynamic Type sizes (fixed 18 Aug 2026: mini player and tab bar use minHeight; EpisodeCard reflows to a vertical layout at accessibility sizes)
- [x] **LYT-16** `LyttejegerTests/LyttejegerTests.swift:1142` — JSON backup has no export-to-import round-trip test (fixed 18 Aug 2026: JSONRoundTripTests covers field-level export-to-import round-trip plus legacy backups)
- [ ] **LYT-17** `Lyttejeger/Services/DataTransferService.swift:222` — importOPML is untested and no service-protocol mock exists in the test target — partially addressed 18 Aug 2026: MockPodcastSearching/MockNRKSearching now exist in ServiceTests.swift; importOPML itself is still untested
- [x] **LYT-18** `Lyttejeger/Services/AudioService.swift:60` — AVAudioSession is activated at app launch and never deactivated, stopping other apps' audio the moment Lyttejeger opens (fixed 18 Aug 2026: activation moved from init to play() and interruption resume; stop() deliberately does not deactivate)
- [ ] **LYT-19** `Lyttejeger/Views/Common/CachedAsyncImage.swift:105` — Artwork is fully decoded and redrawn on the main actor for every image load, causing scroll hitches and transient memory spikes

## P3

- [ ] **LYT-20** `Lyttejeger/Services/AudioService.swift:221` — readyToPlay poll unconditionally restarts playback, overriding a pause issued while the episode was loading
- [ ] **LYT-21** `Lyttejeger/ViewModels/AudioPlayerViewModel.swift:412` — autoAdvanceTask is never reset to nil when popFirst returns nil, permanently disabling auto-advance until the next manual play or stop
- [ ] **LYT-22** `Lyttejeger/Services/AudioService.swift:397` — Remote-command, interruption, and route-change pause paths never set pausedAt, so smart resume silently does not apply to them
- [ ] **LYT-23** `Lyttejeger/Utilities/TimeFormatting.swift:47` — nonisolated(unsafe) global ISO8601DateFormatter is read concurrently from task-group children and the MainActor
- [ ] **LYT-24** `Lyttejeger/Services/DataTransferService.swift:115` — Home screen settings are exported but never imported, so the documented settings round-trip does not exist
- [ ] **LYT-25** `Lyttejeger/Services/DataTransferService.swift:155` — importJSON does not dedupe within the file, so @Attribute(.unique) upserts make the reported counts wrong
- [ ] **LYT-26** `Lyttejeger/Services/DataTransferService.swift:208` — Import is not transactional: no rollback on save failure, and the autosaving mainContext can commit data the user was told failed
- [ ] **LYT-27** `Lyttejeger/Views/Common/MenuView.swift:270` — Import reads the picked file synchronously on the MainActor without a coordinated read
- [ ] **LYT-28** `Lyttejeger/LyttejegerApp.swift:49` — fatalError on container creation becomes a crash loop once a V2 migration stage exists
- [ ] **LYT-29** `Lyttejeger/Services/PodcastIndexAPI.swift:226` — Response body cached before decode validation; undecodable 200 replayed from cache for 5 minutes
- [ ] **LYT-30** `Lyttejeger/Utilities/TTLCache.swift:30` — TTLCache never frees expired entries; API cache holds unbounded bytes of raw Data
- [ ] **LYT-31** `Lyttejeger/Views/Search/HomeView.swift:330` — Per-call since timestamp and mismatched warm-up params make the episodesByFeedIds cache unusable for the Home screen
- [ ] **LYT-32** `Lyttejeger/Services/PodcastIndexAPI.swift:157` — isConfigured and .notConfigured are dead; missing keys surface as a misleading auth failure
- [ ] **LYT-33** `Lyttejeger/Services/NRKPodcastService.swift:64` — NRK catalog refresh failure discards a usable stale catalog instead of degrading gracefully
- [ ] **LYT-34** `Lyttejeger/Services/PodcastIndexAPI.swift:167` — No clock-skew tolerance in SHA1 auth; wrong device clock bricks all Podcast Index features
- [ ] **LYT-35** `Lyttejeger/Services/PodcastIndexAPI.swift:194` — Literal '+' in user queries is not percent-encoded and may be decoded as a space server-side
- [ ] **LYT-36** `Lyttejeger/Services/PodcastIndexAPI.swift:323` — episodesByFeedIds silently truncates to 200 feeds, dropping newest-episode coverage for surplus subscriptions
- [x] **LYT-37** `Lyttejeger/ContentView.swift:141` — pendingPodcastRoute delayed push can double-push and targets whichever tab is active 400ms later (fixed 18 Aug 2026: origin tab captured before the delay, delay skipped when no cover is dismissing, duplicate push guarded)
- [x] **LYT-38** `Lyttejeger/ContentView.swift:60` — Queue tab NavigationStack has no path binding — no pop-to-root, and cross-hierarchy routes must hop to Home (fixed 18 Aug 2026: Kø tab now has a path binding and pops to root on re-tap)
- [ ] **LYT-39** `Lyttejeger/Views/Search/HomeView.swift:65` — loadRecentEpisodes fetches all subscription feeds even when the section is toggled off
- [ ] **LYT-40** `Lyttejeger/Views/Search/HomeView.swift:333` — HomeView and PodcastDetailView do their own networking against singletons, bypassing the protocol-DI seams
- [ ] **LYT-41** `Lyttejeger/Services/DataTransferService.swift:200` — JSON import trusts numeric magnitudes wholesale and has no entry-count cap
- [ ] **LYT-42** `Lyttejeger/Services/OPMLService.swift:86` — XML import parsers rely on implicit hardening defaults and imported files have no size cap
- [ ] **LYT-43** `Lyttejeger/ViewModels/SearchViewModel+PodcastSearch.swift:70` — Podcast ranking scores titles against the synthesized API query, so quoted-phrase queries lose the title-match tier and OR queries rank asymmetrically
- [ ] **LYT-44** `Lyttejeger/Utilities/SearchQueryParser.swift:64` — OR operator interacts wrongly with adjacent quoted phrases and exclusions
- [ ] **LYT-45** `Lyttejeger/Services/PodcastTransform.swift:175` — HTML entity decoding is order-nondeterministic and double-decodes numeric entities behind &
- [ ] **LYT-46** `Lyttejeger/Utilities/TimeFormatting.swift:77` — Future-dated episodes display "0 år siden"
- [ ] **LYT-47** `Lyttejeger/ViewModels/SearchViewModel+PodcastSearch.swift:15` — Queries that parse to no usable API terms silently keep the previous query's results on screen
- [ ] **LYT-48** `Lyttejeger/Data/Categories.swift:102` — Podcast Index category "Spirituality" missing from the category list and translation map
- [ ] **LYT-49** `Lyttejeger/Services/PodcastTransform.swift:78` — No upper bound on feed timestamps lets bogus future dates dominate freshness scoring and the "Nyeste" sort
- [x] **LYT-50** `Lyttejeger/Views/Search/HomeView.swift:103` — Clear-search button has no Norwegian VoiceOver label and a 1.5:1 icon (fixed 18 Aug 2026: Norwegian VoiceOver label added and the icon uses appMutedForeground)
- [x] **LYT-51** `Lyttejeger/Views/Library/QueueView.swift:178` — Queue reorder and add-to-queue exist only in context menus, with no VoiceOver custom actions (fixed 18 Aug 2026: every episode card has a tap-reachable menu button with a Norwegian VoiceOver label; queue actions moved there)
- [ ] **LYT-52** `Lyttejeger/Views/Player/AudioPlayerBar.swift:47` — Anglicism 'podcast' in three user-facing strings; rest of app says 'podkast'
- [ ] **LYT-53** `Lyttejeger/Utilities/TimeFormatting.swift:72` — Relative dates use the calque 'N dager siden' instead of 'for N dager siden'
- [x] **LYT-54** `Lyttejeger/Views/Search/PodcastCard.swift:35` — Explicit-content 'E' badge uses a hardcoded 9pt font that ignores Dynamic Type (fixed 18 Aug 2026: badge uses .badgeText and scales with Dynamic Type)
- [x] **LYT-55** `Lyttejeger/Views/Search/HomeView.swift:90` — Search placeholders use three periods instead of the ellipsis character (fixed 18 Aug 2026: search placeholder uses the ellipsis character)
- [ ] **LYT-56** `Lyttejeger/Theme/Typography.swift:16` — Bold Text accessibility setting has no effect on DM Mono text
- [ ] **LYT-57** `Lyttejeger/Views/Common/MenuView.swift:72` — Import and export rows swap the platform meanings of square.and.arrow.up and square.and.arrow.down
- [ ] **LYT-58** `Lyttejeger/ViewModels/PlaybackProgressViewModel.swift:16` — PlaybackProgressViewModel retention purge deletes user data with zero test coverage
- [x] **LYT-59** `Lyttejeger/Utilities/TTLCache.swift:31` — TTLCache and RateLimiter have no tests despite sitting under every API call (fixed 18 Aug 2026: TTLCache and RateLimiter suites in ServiceTests.swift; PodcastIndexAPI also gained URLProtocol-stubbed behavior tests via an internal init(configuration:) seam)
- [ ] **LYT-60** `LyttejegerTests/LyttejegerTests.swift:165` — blockElementsAsNewlines cannot fail on the regression its name targets
- [ ] **LYT-61** `.github/workflows/test.yml:63` — UI tests are excluded from CI, so their runtime assertions can rot silently — partially mitigated 18 Aug 2026: six deterministic UI tests now pass with stub keys and could join CI via -only-testing:LyttejegerUITests/LyttejegerUITests; LyttejegerNetworkedUITests must stay excluded
- [ ] **LYT-62** `LyttejegerTests/SchemaMigrationTests.swift:9` — SchemaMigrationTests bypass LyttejegerStore.makeContainer while claiming to use it
- [x] **LYT-63** `README.md:31` — README test count stale: claims 75 tests/16 suites, tree has 134 tests/29 suites (fixed 18 Aug 2026: README states 162 tests in 37 suites plus 8 XCUITests)
- [x] **LYT-64** `Personvern.md:3` — Personvern.md content changed in working tree without bumping 'Sist oppdatert' (fixed 18 Aug 2026: Personvern.md dated 18 August 2026)
- [ ] **LYT-65** `project.yml:70` — UIAccessibilityPerformEscapeEnabled is not a documented Info.plist key; inert configuration
- [ ] **LYT-66** `scripts/generate-icons.swift:8` — generate-icons.swift hardcodes a machine-specific absolute path and a source image absent from the repo
- [ ] **LYT-67** `project.yml:18` — Working tree adds a schema retrofit, pinning removal, and browse rework without bumping CURRENT_PROJECT_VERSION past the already-built 14
- [x] **LYT-68** `Brukerveiledning.md:68` — Brukerveiledning's 'Bla uten søkeord' section is stale for the new Episodes-tab browse in the same working tree (fixed 18 Aug 2026: Brukerveiledning covers episode browse and the current NRK filter behaviour)
- [ ] **LYT-69** `Lyttejeger/Views/Common/CachedAsyncImage.swift:106` — NSCache totalCostLimit is inert because images are inserted without a cost
- [ ] **LYT-70** `Lyttejeger/Views/Common/EpisodeCard.swift:38` — Every EpisodeCard body evaluation performs a synchronous SwiftData fetch on the main thread
- [ ] **LYT-71** `Lyttejeger/ViewModels/AudioPlayerViewModel.swift:353` — Position-save loop writes to SwiftData every 5 seconds even while playback is paused
- [ ] **LYT-72** `Lyttejeger/Views/Common/SplashScreenView.swift:32` — Splash overlay blocks interaction for a fixed ~1.6 seconds on every launch
- [ ] **LYT-73** `Lyttejeger/Services/AudioService.swift:1` — AudioService state machine has no unit coverage; deliberate: the file is a do-not-refactor landmine and test seams must not be added. Coverage is limited to the manual audio verification checklist.

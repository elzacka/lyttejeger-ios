# Security Policy

## Reporting a vulnerability

If you discover a security vulnerability in Lyttejeger, please report it responsibly.

**Contact:** hei@tazk.no

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact

I will acknowledge receipt within 48 hours and aim to provide a fix or mitigation plan within 7 days.

## Scope

This policy covers:
- The Lyttejeger iOS application source code
- Build configuration and dependencies
- API key handling and network security

## Out of Scope

- Third-party services (Podcast Index API, NRK)
- Apple platform vulnerabilities
- Social engineering attacks

## Security Practices

### Supply chain & secrets
- **Zero dependencies:** No third-party libraries (zero supply chain risk)
- **API key protection:** Keys are XOR-obfuscated as byte arrays in `Config/Secrets.swift` (gitignored), decoded at runtime via computed properties — never stored as plaintext in source

### Network
- **Certificate pinning:** SHA-256 public key pins for Podcast Index API connections (leaf + intermediate CA) via custom `URLSessionDelegate`
- **HTTPS enforced:** All API calls use HTTPS; `NSAllowsArbitraryLoadsForMedia` enabled only for podcast audio stream URLs
- **Async networking only:** Artwork downloads use `URLSession.shared.data(from:)` — no synchronous `Data(contentsOf:)` calls that block threads
- **Concurrency-limited fetches:** Background refresh caps NRK feed fetches to 4 parallel requests to prevent resource exhaustion
- **Structured logging:** `BackgroundRefreshService` uses `os.Logger` (subsystem `com.Tazk.Lyttejeger`, category `BackgroundRefresh`) for auditable refresh lifecycle logging

### Data
- **Local-only data:** All user data (subscriptions, queue, playback positions) stored on-device via SwiftData — no cloud sync, no analytics, no tracking
- **iPhone-only mode:** `TARGETED_DEVICE_FAMILY: "1"` ensures the app only runs on iPhone. Portrait-only is enforced at runtime via `AppDelegate`

### Data export
- **File protection:** In-app JSON data export uses `.completeFileProtection` — files are only accessible while the device is unlocked
- **Filename sanitization:** Episode audio downloads sanitize titles by stripping `/:\?%*|"<>` characters and limiting to 200 characters

### Concurrency & error handling
- **Strict concurrency:** Full Swift 6 strict concurrency checking (`SWIFT_STRICT_CONCURRENCY: complete`) eliminates data races at compile time
- **Structured logging:** All ViewModels log SwiftData save failures via `os.Logger` (subsystem: `com.Tazk.Lyttejeger`) with `.private` redaction for user data — errors are never silently swallowed
- **User-visible errors:** Search and episode loading surface error messages to the user instead of failing silently

### Input validation
- **Input normalization:** Search query parser normalizes smart punctuation (curly quotes, em/en dashes) to prevent injection of unexpected Unicode

### URL validation
- **HTTPS-only:** `ChapterService` and `TranscriptService` validate that URLs use the `https` scheme before making network requests — non-HTTPS URLs are silently rejected

### Background tasks
- **Isolated context:** Background refresh uses a fresh `ModelContainer` isolated from the main app context

### Data integrity
- **Unique constraints:** `QueueItem.episodeId` uses `@Attribute(.unique)` in SwiftData to prevent duplicate queue entries at the database level

### Testing
- **Unit test coverage:** 50 tests across 12 suites verify pure functions (time formatting, date formatting, search query parsing, HTML-to-text conversion, duration parsing, feed transformation, chapter navigation, transcript lookup, duration filtering, NRK feed detection) to catch regressions in input handling and data transformation

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

- **Zero dependencies:** No third-party libraries (zero supply chain risk)
- **API key protection:** Keys are XOR-obfuscated as byte arrays in `Config/Secrets.swift` (gitignored), decoded at runtime via computed properties — never stored as plaintext in source
- **Certificate pinning:** SHA-256 public key pins for Podcast Index API connections (leaf + intermediate CA) via custom `URLSessionDelegate`
- **Local-only data:** All user data (subscriptions, queue, playback positions) stored on-device via SwiftData — no cloud sync, no analytics, no tracking
- **Network security:** HTTPS enforced for all API calls; `NSAllowsArbitraryLoadsForMedia` enabled only for podcast audio stream URLs
- **Strict concurrency:** Full Swift 6 strict concurrency checking (`SWIFT_STRICT_CONCURRENCY: complete`) eliminates data races at compile time
- **Input normalization:** Search query parser normalizes smart punctuation (curly quotes, em/en dashes) to prevent injection of unexpected Unicode
- **Background tasks:** Background refresh uses a fresh `ModelContainer` isolated from the main app context

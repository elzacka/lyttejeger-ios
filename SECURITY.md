# Security Policy

*Last updated: 31 July 2026*

## Reporting a vulnerability

Report security issues privately to **hei@tazk.no**. Do not open a public issue for undisclosed vulnerabilities.

Please include a description of the issue, steps to reproduce, and the impact you believe it has.

You will get an acknowledgement within 48 hours and an assessment with a fix or mitigation plan within 7 days.

## Supported versions

Lyttejeger ships through the App Store and only the latest release receives fixes.

| Version | Supported |
|---------|-----------|
| 1.0.8 (build 14) | Yes |
| Earlier releases | No, update to the latest version |

## Scope

In scope:

- The Lyttejeger iOS source code in this repository
- Build configuration (`project.yml`, CI workflow) and secret handling
- Network security: certificate pinning, transport security, API authentication

Out of scope:

- Third-party services themselves (Podcast Index, GitHub Pages, podcast hosts)
- Apple platform vulnerabilities
- Social engineering and physical device access
- Findings that require a jailbroken or already-compromised device

## Security model

The app has no accounts, no backend of its own, and no analytics. Every piece of user data stays on the device. That removes most of the usual attack surface, and it means the remaining surface is small enough to describe in full.

**Dependencies.** No third-party libraries. Nothing enters the build that Apple does not ship.

**Secrets.** Podcast Index API keys live in `Config/Secrets.swift`, which is gitignored, stored as XOR-obfuscated byte arrays and decoded at runtime. This is obfuscation, not encryption. It keeps keys out of the repository and out of plain strings in the binary, but anyone with the app binary can recover them. The keys are low-privilege, read-only credentials for a public catalogue, and the threat model accepts this.

**Transport.** Certificate pinning protects connections to `api.podcastindex.org`, matching SHA-256 hashes of the SubjectPublicKeyInfo for the leaf and intermediate certificates. Pinning fails closed: if Podcast Index rotates to a key outside the pin set, all API requests are rejected until an app update ships new pins. All other API and metadata traffic is HTTPS. `NSAllowsArbitraryLoadsForMedia` is deliberately enabled, because a large share of podcast hosts still serve audio over plain HTTP; this exception applies only to media playback and download.

**Data at rest.** User data is stored locally via SwiftData. The JSON export written by the in-app export function uses `.completeFileProtection`, so it is readable only while the device is unlocked.

**Concurrency.** The project builds with `SWIFT_STRICT_CONCURRENCY: complete`, which eliminates data races at compile time.

### Known limitations

- API keys are recoverable from the app binary, as described above
- Audio streams may travel over plain HTTP when the podcast host offers nothing better
- Protection of local data relies on iOS file protection and the device passcode

## Operational note for maintainers

Certificate pins are a fail-closed dependency on an external certificate chain. Before every release, verify that the pins in `PodcastIndexAPI.swift` still match the live chain. The command is documented in a comment in that file. Shipping stale pins takes the app offline for every user.

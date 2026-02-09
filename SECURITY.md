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

- No third-party dependencies (zero supply chain risk)
- API keys are excluded from version control via `.gitignore`
- Certificate pinning for API connections
- All data stored locally on device (no cloud sync)
- Privacy manifest declares all accessed APIs

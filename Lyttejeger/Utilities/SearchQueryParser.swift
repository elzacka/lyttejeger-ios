import Foundation

struct ParsedQuery: Sendable {
    var mustInclude: [String] = []
    var shouldInclude: [String] = []
    var mustExclude: [String] = []
    var exactPhrases: [String] = []
}

/// Parse search query with advanced syntax:
/// - AND: default (space-separated terms)
/// - OR: "term1 OR term2" (case-insensitive)
/// - Exact phrase: "quoted phrase" or «quoted phrase»
/// - Exclusion: -term (only at word boundary, not mid-word hyphens)
enum SearchQueryParser {
    // Compiled once at app startup — pattern is a simple character class with no backtracking risk
    private static let quotePattern = try! NSRegularExpression(pattern: "\"([^\"]+)\"")

    static func parse(_ query: String) -> ParsedQuery {
        var result = ParsedQuery()
        // Normalize all quotation mark variants to ASCII straight double quote:
        // - iOS smart quotes (auto-replaced by keyboard)
        // - Norwegian guillemets « » (standard Norwegian quotation marks)
        // - Low-9 quotes „ (German/Polish keyboards)
        // - Single guillemets ‹ › (rare but possible)
        // Normalize dash variants to ASCII hyphen-minus:
        // - En-dash (iOS auto-replaces hyphen in some contexts)
        // - Em-dash
        let normalized = query
            .replacingOccurrences(of: "\u{2013}", with: "-")   // en-dash
            .replacingOccurrences(of: "\u{2014}", with: "-")   // em-dash
            .replacingOccurrences(of: "\u{201C}", with: "\"")  // left smart quote
            .replacingOccurrences(of: "\u{201D}", with: "\"")  // right smart quote
            .replacingOccurrences(of: "\u{00AB}", with: "\"")  // left guillemet «
            .replacingOccurrences(of: "\u{00BB}", with: "\"")  // right guillemet »
            .replacingOccurrences(of: "\u{201E}", with: "\"")  // low-9 double quote „
            .replacingOccurrences(of: "\u{2039}", with: "\"")  // single left guillemet ‹
            .replacingOccurrences(of: "\u{203A}", with: "\"")  // single right guillemet ›
            .replacingOccurrences(of: "\u{2018}", with: "'")   // left single smart quote
            .replacingOccurrences(of: "\u{2019}", with: "'")   // right single smart quote
        let trimmed = normalized.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return result }

        // Extract quoted phrases first
        var remaining = trimmed
        let matches = quotePattern.matches(in: remaining, range: NSRange(remaining.startIndex..., in: remaining))

        for match in matches.reversed() {
            if let phraseRange = Range(match.range(at: 1), in: remaining) {
                result.exactPhrases.append(String(remaining[phraseRange]))
            }
            if let fullRange = Range(match.range, in: remaining) {
                remaining.removeSubrange(fullRange)
            }
        }

        // Split remaining by whitespace
        let tokens = remaining.split(separator: " ").map(String.init)

        var i = 0
        while i < tokens.count {
            let token = tokens[i]

            if token.uppercased() == "OR" {
                // Next token is OR alternative (case-insensitive: "OR", "or", "Or")
                i += 1
                if i < tokens.count {
                    result.shouldInclude.append(tokens[i])
                }
            } else if token.hasPrefix("-") && token.count > 1 {
                // Exclusion: only when `-` is at the start of a token (word boundary).
                // Mid-word hyphens (e.g., "covid-19", "e-post") are handled below
                // by reaching this point only after split-by-space — so "covid-19"
                // is a single token starting with "c", not "-".
                result.mustExclude.append(String(token.dropFirst()))
            } else if !token.isEmpty {
                // Check if next token is OR (case-insensitive)
                if i + 1 < tokens.count && tokens[i + 1].uppercased() == "OR" {
                    result.shouldInclude.append(token)
                } else {
                    result.mustInclude.append(token)
                }
            }

            i += 1
        }

        return result
    }
}

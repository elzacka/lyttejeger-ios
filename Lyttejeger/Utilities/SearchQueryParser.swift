import Foundation

struct ParsedQuery: Sendable {
    var mustInclude: [String] = []
    var shouldInclude: [String] = []
    var mustExclude: [String] = []
    var exactPhrases: [String] = []
}

/// Parse search query with advanced syntax:
/// - AND: default (space-separated terms)
/// - OR: "term1 OR term2"
/// - Exact phrase: "quoted phrase"
/// - Exclusion: -term
enum SearchQueryParser {
    // Compiled once at app startup — pattern is a simple character class with no backtracking risk
    private static let quotePattern = try! NSRegularExpression(pattern: "\"([^\"]+)\"")

    static func parse(_ query: String) -> ParsedQuery {
        var result = ParsedQuery()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
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

            if token == "OR" {
                // Next token is OR alternative
                i += 1
                if i < tokens.count {
                    result.shouldInclude.append(tokens[i])
                }
            } else if token.hasPrefix("-") && token.count > 1 {
                // Exclusion
                result.mustExclude.append(String(token.dropFirst()))
            } else if !token.isEmpty {
                // Check if next token is OR
                if i + 1 < tokens.count && tokens[i + 1] == "OR" {
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

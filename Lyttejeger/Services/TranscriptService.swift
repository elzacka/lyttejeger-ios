import Foundation

struct TranscriptSegment: Identifiable, Sendable {
    var id: String { "\(startTime)-\(text.prefix(20))" }
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var speaker: String?
}

struct Transcript: Sendable {
    var segments: [TranscriptSegment]
    var language: String?
}

actor TranscriptService {
    static let shared = TranscriptService()

    private static let cacheTTL: TimeInterval = 30 * 60 // 30 minutes
    private var cache: [String: (transcript: Transcript, fetchedAt: Date)] = [:]
    private static let timestampRegex = try! NSRegularExpression(
        pattern: "(\\d{2}:)?(\\d{2}):(\\d{2})[.,](\\d{3})\\s*-->\\s*(\\d{2}:)?(\\d{2}):(\\d{2})[.,](\\d{3})"
    )

    func fetchTranscript(from url: String) async -> Transcript? {
        guard !url.isEmpty,
              let requestUrl = URL(string: url),
              requestUrl.scheme == "https" else { return nil }

        // Check cache
        if let cached = cache[url],
           Date().timeIntervalSince(cached.fetchedAt) < Self.cacheTTL {
            return cached.transcript
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: requestUrl)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard data.count <= AppConstants.maxTranscriptSize else { return nil }

            let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
            let text = String(data: data, encoding: .utf8) ?? ""

            // Detect format
            if contentType.contains("json") || url.hasSuffix(".json") {
                if let result = parseJSON(text), !result.segments.isEmpty {
                    storeInCache(url: url, transcript: result)
                    return result
                }
            } else if url.hasSuffix(".vtt") || contentType.contains("vtt") || text.contains("WEBVTT") {
                let result = parseVTT(text)
                if !result.segments.isEmpty {
                    storeInCache(url: url, transcript: result)
                    return result
                }
            } else if url.hasSuffix(".srt") || String(text.prefix(500)).range(of: "\\d+\\n\\d{2}:\\d{2}:\\d{2}", options: .regularExpression) != nil {
                let result = parseSRT(text)
                if !result.segments.isEmpty {
                    storeInCache(url: url, transcript: result)
                    return result
                }
            }

            // Try all formats
            if let result = parseJSON(text), !result.segments.isEmpty {
                storeInCache(url: url, transcript: result)
                return result
            }
            let vtt = parseVTT(text)
            if !vtt.segments.isEmpty {
                storeInCache(url: url, transcript: vtt)
                return vtt
            }
            let srt = parseSRT(text)
            if !srt.segments.isEmpty {
                storeInCache(url: url, transcript: srt)
                return srt
            }

            return nil
        } catch {
            return nil
        }
    }

    func clearCache() {
        cache.removeAll()
    }

    private func storeInCache(url: String, transcript: Transcript) {
        cache[url] = (transcript: transcript, fetchedAt: Date())
        if cache.count > AppConstants.transcriptCacheMaxSize {
            let sorted = cache.sorted { $0.value.fetchedAt < $1.value.fetchedAt }
            for entry in sorted.prefix(cache.count - AppConstants.transcriptCacheMaxSize) {
                cache.removeValue(forKey: entry.key)
            }
        }
    }

    // MARK: - JSON Parser

    private func parseJSON(_ text: String) -> Transcript? {
        guard let data = text.data(using: .utf8) else { return nil }

        // Try array format
        if let items = try? JSONDecoder().decode([JSONSegment].self, from: data) {
            return Transcript(segments: items.map { item in
                TranscriptSegment(
                    startTime: item.startTime ?? item.start ?? 0,
                    endTime: item.endTime ?? item.end ?? (item.startTime ?? 0) + 5,
                    text: item.body ?? item.text ?? "",
                    speaker: item.speaker
                )
            })
        }

        // Try object with segments
        if let obj = try? JSONDecoder().decode(JSONTranscript.self, from: data) {
            return Transcript(
                segments: obj.segments.map { seg in
                    TranscriptSegment(
                        startTime: seg.startTime ?? seg.start ?? 0,
                        endTime: seg.endTime ?? seg.end ?? (seg.startTime ?? 0) + 5,
                        text: seg.body ?? seg.text ?? "",
                        speaker: seg.speaker
                    )
                },
                language: obj.language
            )
        }

        return nil
    }

    // MARK: - VTT Parser

    private func parseVTT(_ text: String) -> Transcript {
        var segments: [TranscriptSegment] = []
        let lines = text.components(separatedBy: .newlines)
        var currentStart: TimeInterval = 0
        var currentEnd: TimeInterval = 0
        var currentText: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "WEBVTT" || trimmed.isEmpty || trimmed.hasPrefix("NOTE") {
                if !currentText.isEmpty {
                    segments.append(TranscriptSegment(
                        startTime: currentStart,
                        endTime: currentEnd,
                        text: currentText.joined(separator: " ")
                    ))
                    currentText = []
                }
                continue
            }

            if let times = parseTimestampLine(trimmed) {
                if !currentText.isEmpty {
                    segments.append(TranscriptSegment(
                        startTime: currentStart,
                        endTime: currentEnd,
                        text: currentText.joined(separator: " ")
                    ))
                    currentText = []
                }
                currentStart = times.0
                currentEnd = times.1
                continue
            }

            if trimmed.range(of: "^\\d+$", options: .regularExpression) != nil { continue }

            if !trimmed.isEmpty {
                currentText.append(trimmed)
            }
        }

        if !currentText.isEmpty {
            segments.append(TranscriptSegment(
                startTime: currentStart,
                endTime: currentEnd,
                text: currentText.joined(separator: " ")
            ))
        }

        return Transcript(segments: segments)
    }

    // MARK: - SRT Parser

    private func parseSRT(_ text: String) -> Transcript {
        var segments: [TranscriptSegment] = []
        let blocks = text.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
            guard lines.count >= 2 else { continue }

            var timestampLine: String?
            var textLines: [String] = []

            for line in lines {
                if timestampLine == nil && line.contains("-->") {
                    timestampLine = line
                } else if timestampLine != nil {
                    textLines.append(line.trimmingCharacters(in: .whitespaces))
                }
            }

            guard let ts = timestampLine, let times = parseTimestampLine(ts) else { continue }

            segments.append(TranscriptSegment(
                startTime: times.0,
                endTime: times.1,
                text: textLines.joined(separator: " ")
            ))
        }

        return Transcript(segments: segments)
    }

    // MARK: - Timestamp Parsing

    private func parseTimestampLine(_ line: String) -> (TimeInterval, TimeInterval)? {
        guard let match = Self.timestampRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        func extractTime(hourGroup: Int, minGroup: Int, secGroup: Int, msGroup: Int) -> TimeInterval? {
            let hourStr: String
            if match.range(at: hourGroup).location != NSNotFound,
               let hourRange = Range(match.range(at: hourGroup), in: line) {
                hourStr = String(line[hourRange]).replacingOccurrences(of: ":", with: "")
            } else {
                hourStr = "0"
            }
            guard let minRange = Range(match.range(at: minGroup), in: line),
                  let secRange = Range(match.range(at: secGroup), in: line),
                  let msRange = Range(match.range(at: msGroup), in: line),
                  let hours = Double(hourStr),
                  let mins = Double(String(line[minRange])),
                  let secs = Double(String(line[secRange])),
                  let ms = Double(String(line[msRange])) else {
                return nil
            }
            return hours * 3600 + mins * 60 + secs + ms / 1000
        }

        guard let start = extractTime(hourGroup: 1, minGroup: 2, secGroup: 3, msGroup: 4),
              let end = extractTime(hourGroup: 5, minGroup: 6, secGroup: 7, msGroup: 8) else {
            return nil
        }
        return (start, end)
    }

    // MARK: - Helpers

    static func getCurrentSegment(_ transcript: Transcript, at time: TimeInterval) -> TranscriptSegment? {
        // Exact match first
        if let exact = transcript.segments.first(where: { time >= $0.startTime && time < $0.endTime }) {
            return exact
        }
        // Fall back to most recent segment (handles gaps between segments)
        return transcript.segments.last { time >= $0.startTime }
    }

}

// MARK: - JSON Decodable Types

private struct JSONSegment: Decodable {
    let startTime: Double?
    let start: Double?
    let endTime: Double?
    let end: Double?
    let body: String?
    let text: String?
    let speaker: String?
}

private struct JSONTranscript: Decodable {
    let segments: [JSONSegment]
    let language: String?
}

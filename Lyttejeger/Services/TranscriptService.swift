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

    func fetchTranscript(from url: String) async -> Transcript? {
        guard !url.isEmpty, let requestUrl = URL(string: url) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: requestUrl)
            let contentType = (response as? HTTPURLResponse)?
                .value(forHTTPHeaderField: "Content-Type") ?? ""
            let text = String(data: data, encoding: .utf8) ?? ""

            // Detect format
            if contentType.contains("json") || url.hasSuffix(".json") {
                if let result = parseJSON(text), !result.segments.isEmpty { return result }
            } else if url.hasSuffix(".vtt") || contentType.contains("vtt") || text.contains("WEBVTT") {
                let result = parseVTT(text)
                if !result.segments.isEmpty { return result }
            } else if url.hasSuffix(".srt") || text.range(of: "\\d+\\n\\d{2}:\\d{2}:\\d{2}", options: .regularExpression) != nil {
                let result = parseSRT(text)
                if !result.segments.isEmpty { return result }
            }

            // Try all formats
            if let result = parseJSON(text), !result.segments.isEmpty { return result }
            let vtt = parseVTT(text)
            if !vtt.segments.isEmpty { return vtt }
            let srt = parseSRT(text)
            if !srt.segments.isEmpty { return srt }

            return nil
        } catch {
            return nil
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
        let pattern = "(\\d{2}:)?(\\d{2}):(\\d{2})[.,](\\d{3})\\s*-->\\s*(\\d{2}:)?(\\d{2}):(\\d{2})[.,](\\d{3})"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        func extractTime(hourGroup: Int, minGroup: Int, secGroup: Int, msGroup: Int) -> TimeInterval {
            let hourStr = match.range(at: hourGroup).location != NSNotFound
                ? String(line[Range(match.range(at: hourGroup), in: line)!]).replacingOccurrences(of: ":", with: "")
                : "0"
            let minStr = String(line[Range(match.range(at: minGroup), in: line)!])
            let secStr = String(line[Range(match.range(at: secGroup), in: line)!])
            let msStr = String(line[Range(match.range(at: msGroup), in: line)!])
            return Double(hourStr)! * 3600 + Double(minStr)! * 60 + Double(secStr)! + Double(msStr)! / 1000
        }

        let start = extractTime(hourGroup: 1, minGroup: 2, secGroup: 3, msGroup: 4)
        let end = extractTime(hourGroup: 5, minGroup: 6, secGroup: 7, msGroup: 8)
        return (start, end)
    }

    // MARK: - Helpers

    static func getCurrentSegment(_ transcript: Transcript, at time: TimeInterval) -> TranscriptSegment? {
        transcript.segments.first { time >= $0.startTime && time < $0.endTime }
    }

    static func searchTranscript(_ segments: [TranscriptSegment], query: String) -> [TranscriptSegment] {
        let lower = query.lowercased()
        return segments.filter { $0.text.lowercased().contains(lower) }
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

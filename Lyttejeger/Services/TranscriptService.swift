import Foundation

struct TranscriptSegment: Identifiable, Sendable {
    let id: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var speaker: String?

    init(startTime: TimeInterval, endTime: TimeInterval, text: String, speaker: String? = nil) {
        self.id = UUID().uuidString
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.speaker = speaker
    }
}

struct Transcript: Sendable {
    var segments: [TranscriptSegment]
    var language: String?
    /// False for transcripts that carry text but no timing — common for
    /// hand-written HTML ones. They are worth reading, but nothing about them
    /// can follow playback, so the panel must not offer highlighting,
    /// tap-to-seek or auto-scroll on them.
    var isSynced: Bool = true
}

enum TranscriptError: Error {
    case unavailable
}

actor TranscriptService: TranscriptFetching {
    static let shared = TranscriptService()

    private static let cacheTTL: TimeInterval = 30 * 60 // 30 minutes
    private var cache = TTLCache<Transcript>(
        ttl: TranscriptService.cacheTTL,
        maxSize: AppConstants.transcriptCacheMaxSize
    )
    private static let timestampRegex = try! NSRegularExpression(
        pattern: "(\\d{2}:)?(\\d{2}):(\\d{2})[.,](\\d{3})\\s*-->\\s*(\\d{2}:)?(\\d{2}):(\\d{2})[.,](\\d{3})"
    )

    /// The three tags Podcasting 2.0 HTML transcripts are built from, matched in
    /// document order so a `<p>` can be paired with the `<time>` and `<cite>`
    /// that precede it.
    private static let htmlPartRegex = try! NSRegularExpression(
        pattern: "<(cite|time|p)\\b[^>]*>(.*?)</\\1>",
        options: [.dotMatchesLineSeparators, .caseInsensitive]
    )

    /// `<v Speaker>` opens a voice span in WebVTT. Captured so the name becomes
    /// a speaker label instead of leaking into the cue text as markup.
    private static let vttVoiceRegex = try! NSRegularExpression(
        pattern: "<v\\s+([^>]+)>",
        options: [.caseInsensitive]
    )

    private enum Format {
        case json, vtt, srt, html, plain
    }

    /// The app shares the process-wide session; tests pass a configuration
    /// carrying a stubbed URLProtocol. Same seam as `PodcastIndexAPI`.
    private let session: URLSession

    init(configuration: URLSessionConfiguration? = nil) {
        session = configuration.map { URLSession(configuration: $0) } ?? .shared
    }

    func fetchTranscript(from url: String) async throws -> Transcript? {
        guard !url.isEmpty,
              let requestUrl = URL(string: url),
              requestUrl.scheme == "https" else { throw TranscriptError.unavailable }

        // Check cache
        if let cached = cache.value(for: url) {
            return cached
        }

        do {
            let (data, response) = try await session.data(from: requestUrl)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw TranscriptError.unavailable
            }
            guard data.count <= AppConstants.maxTranscriptSize else { throw TranscriptError.unavailable }

            let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()

            // Fetched and read, but nothing usable in it — that is
            // "no transcript", not a failure.
            guard let transcript = Self.makeTranscript(from: data, contentType: contentType, url: url) else {
                return nil
            }

            storeInCache(url: url, transcript: transcript)
            return transcript
        } catch is TranscriptError {
            throw TranscriptError.unavailable
        } catch {
            throw TranscriptError.unavailable
        }
    }

    func clearCache() {
        cache.removeAll()
    }

    private func storeInCache(url: String, transcript: Transcript) {
        cache.insert(transcript, for: url)
    }

    // MARK: - Parse pipeline

    /// Everything between "bytes arrived" and "a transcript worth showing".
    /// Kept free of network and actor state so it can be exercised directly.
    static func makeTranscript(from data: Data, contentType: String, url: String) -> Transcript? {
        guard let text = decodeText(data) else { return nil }
        // `parse` already normalised and rejected the empty result.
        return parse(text, contentType: contentType.lowercased(), url: url)
    }

    // MARK: - Text decoding

    /// Norwegian transcripts are regularly served as ISO-8859-1 or Windows-1252
    /// without saying so. Decoding those as UTF-8 alone yields nil, which used
    /// to surface as "this episode has no transcript".
    static func decodeText(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let cp1252 = String(data: data, encoding: .windowsCP1252) { return cp1252 }
        return String(data: data, encoding: .isoLatin1)
    }

    // MARK: - Format dispatch

    /// Tries the format the server and file name claim first, then the others.
    /// Every parser returns nil unless it actually recognised its own format,
    /// so an unparseable file is reported as "no transcript" rather than being
    /// swallowed whole into a single bogus cue.
    private static func parse(_ text: String, contentType: String, url: String) -> Transcript? {
        let lower = url.lowercased()
        let order: [Format]

        if contentType.contains("json") || lower.hasSuffix(".json") {
            order = [.json, .vtt, .srt, .html]
        } else if contentType.contains("vtt") || lower.hasSuffix(".vtt") {
            order = [.vtt, .srt, .json, .html]
        } else if contentType.contains("srt") || lower.hasSuffix(".srt") {
            order = [.srt, .vtt, .json, .html]
        } else if contentType.contains("html") || lower.hasSuffix(".html") || lower.hasSuffix(".htm") {
            order = [.html, .json, .vtt, .srt]
        } else {
            order = [.json, .vtt, .srt, .html]
        }

        // Plain text is always the last thing tried: it recognises no format of
        // its own, so it must never pre-empt a parser that would.
        for format in order + [.plain] {
            guard let result = parse(text, as: format) else { continue }
            // Normalising here, not at the end of the pipeline, is what keeps
            // the fallback alive: a parser can return structurally valid
            // segments that are all empty, and accepting those stopped the
            // remaining formats from ever being tried.
            let segments = normalize(result.segments, isSynced: result.isSynced)
            guard !segments.isEmpty else { continue }
            return Transcript(segments: segments, language: result.language, isSynced: result.isSynced)
        }
        return nil
    }

    private static func parse(_ text: String, as format: Format) -> Transcript? {
        switch format {
        case .json: return parseJSON(text)
        case .vtt: return parseVTT(text)
        case .srt: return parseSRT(text)
        case .html: return parseHTML(text)
        case .plain: return parsePlainText(text)
        }
    }

    // MARK: - Plain-text fallback

    /// A transcript with no timings and no markup worth parsing.
    ///
    /// `transcriptRank` prefers `text/plain` over an unknown type, so one can
    /// legitimately be the best transcript on offer. Every other parser
    /// requires evidence of its own format, so without this such a file was
    /// selected and then reported as "no transcript".
    private static let minPlainTextCharacters = 500

    static func parsePlainText(_ text: String) -> Transcript? {
        // Run it through the HTML stripper regardless: a page built from tags
        // this parser does not know would otherwise render as raw markup.
        let stripped = PodcastTransform.htmlToText(text)
        // Length is the only signal separating a real untimed transcript from
        // a server error page, and it is a decisive one: minutes of speech run
        // to thousands of characters, while "404 Not Found" runs to seventy.
        guard stripped.count >= Self.minPlainTextCharacters,
              stripped.contains(where: \.isLetter) else { return nil }

        var blocks = Self.paragraphs(in: stripped, separatedBy: "\n\n")
        if blocks.count < 2 {
            blocks = Self.paragraphs(in: stripped, separatedBy: "\n")
        }
        guard !blocks.isEmpty else { return nil }

        return Transcript(
            segments: blocks.map { TranscriptSegment(startTime: 0, endTime: 0, text: $0, speaker: nil) },
            isSynced: false
        )
    }

    private static func paragraphs(in text: String, separatedBy separator: String) -> [String] {
        text.components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - JSON Parser

    private static func parseJSON(_ text: String) -> Transcript? {
        guard let data = text.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()

        // Try array format
        if let items = try? decoder.decode([JSONSegment].self, from: data), !items.isEmpty {
            return Transcript(segments: items.map(Self.segment(from:)))
        }

        // Try object with segments
        if let obj = try? decoder.decode(JSONTranscript.self, from: data), !obj.segments.isEmpty {
            return Transcript(
                segments: obj.segments.map(Self.segment(from:)),
                language: obj.language
            )
        }

        return nil
    }

    private static func segment(from item: JSONSegment) -> TranscriptSegment {
        let start = item.startTime ?? item.start ?? 0
        let speaker = item.speaker?.trimmingCharacters(in: .whitespacesAndNewlines)
        return TranscriptSegment(
            startTime: start,
            endTime: item.endTime ?? item.end ?? start,
            text: (item.body ?? item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            speaker: speaker?.isEmpty == false ? speaker : nil
        )
    }

    // MARK: - HTML Parser

    /// Podcasting 2.0 HTML transcripts are a flat run of `<cite>` (speaker),
    /// `<time>` (start) and `<p>` (what was said). Without this, such a file
    /// fell through to the VTT parser, which has no timestamps to find in it
    /// and so rendered the raw markup as one long "cue".
    static func parseHTML(_ text: String) -> Transcript? {
        let range = NSRange(text.startIndex..., in: text)
        var segments: [TranscriptSegment] = []
        var pendingSpeaker: String?
        var pendingStart: TimeInterval?
        var sawTime = false

        Self.htmlPartRegex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match,
                  let tagRange = Range(match.range(at: 1), in: text),
                  let bodyRange = Range(match.range(at: 2), in: text) else { return }

            let tag = text[tagRange].lowercased()
            let body = PodcastTransform.htmlToText(String(text[bodyRange]))
            guard !body.isEmpty else { return }

            switch tag {
            case "cite":
                pendingSpeaker = body
            case "time":
                if let seconds = Self.parseClock(body) {
                    pendingStart = seconds
                    sawTime = true
                }
            case "p":
                // The timestamp is deliberately not cleared: a speaker turn
                // routinely spans several paragraphs, and clearing it dropped
                // every paragraph after the first onto 0:00 — which then sorted
                // them to the top of the transcript.
                segments.append(TranscriptSegment(
                    startTime: pendingStart ?? 0,
                    endTime: pendingStart ?? 0,
                    text: body,
                    speaker: pendingSpeaker
                ))
            default:
                break
            }
        }

        guard !segments.isEmpty else { return nil }
        // Plenty of publishers hand-write an HTML transcript with no `<time>`
        // at all. That is still worth reading, so it is kept and flagged as
        // unsynced rather than discarded or faked onto 0:00.
        return Transcript(segments: segments, isSynced: sawTime)
    }

    /// Parses `HH:MM:SS` or `MM:SS`.
    ///
    /// A bare number is rejected on purpose. Publishers put ordinary `<time>`
    /// elements in the page chrome, and reading `<time>2024</time>` as 2024
    /// seconds marked the whole transcript as synced with nonsense timings
    /// instead of letting it fall back to plain reading order.
    static func parseClock(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":")
        guard parts.count >= 2, parts.count <= 3 else { return nil }

        var seconds: TimeInterval = 0
        for part in parts {
            guard let value = Double(part) else { return nil }
            seconds = seconds * 60 + value
        }
        return seconds
    }

    // MARK: - VTT Parser

    static func parseVTT(_ text: String) -> Transcript? {
        var segments: [TranscriptSegment] = []
        let lines = text.components(separatedBy: .newlines)
        var currentStart: TimeInterval = 0
        var currentEnd: TimeInterval = 0
        var currentText: [String] = []
        var currentSpeaker: String?
        var sawTimestamp = false

        func flush() {
            guard !currentText.isEmpty else { return }
            let joined = currentText.joined(separator: " ")
            let (body, speaker) = Self.extractVTTSpeaker(joined)
            segments.append(TranscriptSegment(
                startTime: currentStart,
                endTime: currentEnd,
                text: body,
                speaker: speaker ?? currentSpeaker
            ))
            currentText = []
            currentSpeaker = nil
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "WEBVTT" || trimmed.isEmpty || trimmed.hasPrefix("NOTE") {
                flush()
                continue
            }

            if let times = parseTimestampLine(trimmed) {
                flush()
                sawTimestamp = true
                currentStart = times.0
                currentEnd = times.1
                continue
            }

            if trimmed.range(of: "^\\d+$", options: .regularExpression) != nil { continue }

            // Only collect text once a timestamp has established when it plays.
            // Otherwise any non-VTT file would be swallowed as one long cue.
            guard sawTimestamp else { continue }
            currentText.append(trimmed)
        }

        flush()

        guard sawTimestamp, !segments.isEmpty else { return nil }
        return Transcript(segments: segments)
    }

    /// Pulls the name out of a `<v Speaker>` span and strips any remaining
    /// inline markup, so cue styling never reaches the screen as text.
    private static func extractVTTSpeaker(_ line: String) -> (String, String?) {
        var speaker: String?
        let range = NSRange(line.startIndex..., in: line)
        if let match = vttVoiceRegex.firstMatch(in: line, range: range),
           let nameRange = Range(match.range(at: 1), in: line) {
            speaker = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        }
        return (PodcastTransform.htmlToText(line), speaker?.isEmpty == false ? speaker : nil)
    }

    // MARK: - SRT Parser

    static func parseSRT(_ text: String) -> Transcript? {
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

            let (body, speaker) = Self.extractVTTSpeaker(textLines.joined(separator: " "))
            segments.append(TranscriptSegment(
                startTime: times.0,
                endTime: times.1,
                text: body,
                speaker: speaker
            ))
        }

        guard !segments.isEmpty else { return nil }
        return Transcript(segments: segments)
    }

    // MARK: - Timestamp Parsing

    private static func parseTimestampLine(_ line: String) -> (TimeInterval, TimeInterval)? {
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

    // MARK: - Normalisation

    /// Cleans up whatever the parsers produced: drops blanks, orders by time,
    /// gives every cue a usable end time, and folds word-level input into
    /// readable cues.
    static func normalize(_ segments: [TranscriptSegment], isSynced: Bool = true) -> [TranscriptSegment] {
        let cleaned = segments
            .map { segment -> TranscriptSegment in
                var copy = segment
                copy.text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return copy
            }
            .filter { !$0.text.isEmpty && $0.startTime >= 0 }

        guard !cleaned.isEmpty else { return [] }

        // An unsynced transcript has no times to order by, and `sorted` is not
        // stable — sorting it would scramble the paragraphs into a random
        // reading order. Document order is the only order it has.
        guard isSynced else { return cleaned }

        // Enumerate first so equal start times keep the order the file gave
        // them, which a plain `sorted` does not guarantee.
        let ordered = cleaned.enumerated()
            .sorted { ($0.element.startTime, $0.offset) < ($1.element.startTime, $1.offset) }
            .map(\.element)

        return closeGaps(mergeWordLevel(ordered))
    }

    /// A cue whose end is not after its start can never be the current one,
    /// because lookup is `start <= time < end`. Borrow the next cue's start,
    /// but only when it actually lies ahead: neighbouring cues sharing a
    /// timestamp would otherwise keep a zero-length window and stay
    /// unreachable.
    private static func closeGaps(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        var result = segments
        for index in result.indices where result[index].endTime <= result[index].startTime {
            let start = result[index].startTime
            let next = index + 1 < result.count ? result[index + 1].startTime : nil
            if let next, next > start {
                result[index].endTime = next
            } else {
                result[index].endTime = start + estimatedDuration(result[index].text)
            }
        }
        return result
    }

    /// Roughly 2.5 words a second, floored so a very short cue still has a
    /// window in which it counts as current.
    private static func estimatedDuration(_ text: String) -> TimeInterval {
        let words = text.split(separator: " ").count
        return max(2, Double(words) / 2.5)
    }

    // MARK: - Word-level merging

    private static let maxCueCharacters = 180
    private static let maxCueDuration: TimeInterval = 18
    private static let maxCueGap: TimeInterval = 2
    private static let minCueCharacters = 40

    /// Automatic transcription services commonly emit one segment per spoken
    /// word. Rendered as-is that is hundreds of one-word rows, each with its
    /// own divider and tap target. Publisher-authored cues are left untouched.
    static func mergeWordLevel(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        guard isWordLevel(segments) else { return segments }

        var merged: [TranscriptSegment] = []
        var buffer: [TranscriptSegment] = []

        func flush() {
            guard let first = buffer.first, let last = buffer.last else { return }
            merged.append(TranscriptSegment(
                startTime: first.startTime,
                endTime: max(last.endTime, first.startTime),
                text: buffer.map(\.text).joined(separator: " "),
                speaker: first.speaker
            ))
            buffer = []
        }

        for segment in segments {
            if let last = buffer.last {
                let characters = buffer.reduce(0) { $0 + $1.text.count + 1 }
                let duration = max(last.endTime, segment.startTime) - (buffer.first?.startTime ?? 0)
                let gap = segment.startTime - last.endTime
                let endsSentence = last.text.hasSuffix(".") || last.text.hasSuffix("!")
                    || last.text.hasSuffix("?") || last.text.hasSuffix("\u{2026}")

                if segment.speaker != last.speaker
                    || gap > maxCueGap
                    || characters >= maxCueCharacters
                    || duration >= maxCueDuration
                    || (endsSentence && characters >= minCueCharacters) {
                    flush()
                }
            }
            buffer.append(segment)
        }
        flush()

        return merged
    }

    /// Treats input as word-level when most cues are a single word. A handful
    /// of one-word cues is normal in any transcript, so this needs a clear
    /// majority and enough segments to judge.
    static func isWordLevel(_ segments: [TranscriptSegment]) -> Bool {
        guard segments.count > 10 else { return false }
        let singleWord = segments.reduce(into: 0) { count, segment in
            if !segment.text.contains(" ") { count += 1 }
        }
        return singleWord * 10 >= segments.count * 6
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

import Foundation

enum ChapterError: Error {
    case unavailable
}

actor ChapterService: ChapterFetching {
    static let shared = ChapterService()

    private var cache = TTLCache<[Chapter]>(ttl: AppConstants.chapterCacheTTL, maxSize: AppConstants.chapterCacheMaxSize)

    /// The app shares the process-wide session; tests pass a configuration
    /// carrying a stubbed URLProtocol. Same seam as `PodcastIndexAPI`.
    private let session: URLSession

    init(configuration: URLSessionConfiguration? = nil) {
        session = configuration.map { URLSession(configuration: $0) } ?? .shared
    }

    func fetchChapters(from url: String) async throws -> [Chapter] {
        guard !url.isEmpty,
              let requestUrl = URL(string: url),
              requestUrl.scheme == "https" else { throw ChapterError.unavailable }

        // Check cache
        if let cached = cache.value(for: url) {
            return cached
        }

        do {
            let (data, urlResponse) = try await session.data(from: requestUrl)
            guard let http = urlResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw ChapterError.unavailable
            }
            guard data.count <= AppConstants.maxChaptersSize else { throw ChapterError.unavailable }

            guard let chapters = Self.makeChapters(from: data) else { throw ChapterError.unavailable }

            cache.insert(chapters, for: url)
            return chapters
        } catch {
            throw ChapterError.unavailable
        }
    }

    /// The decode-and-clean pipeline, free of network and actor state.
    /// Returns nil only when the payload is not a chapters file at all — an
    /// empty result means "this episode has no chapters to show".
    static func makeChapters(from data: Data) -> [Chapter]? {
        guard let entries = decodeEntries(data) else { return nil }
        return makeChapters(from: entries)
    }

    /// The spec wraps the list in an object, but feeds in the wild also serve a
    /// bare array. Accepting both is the difference between a chapter list and
    /// a "could not load" message.
    private static func decodeEntries(_ data: Data) -> [ChapterEntry]? {
        let decoder = JSONDecoder()
        if let response = try? decoder.decode(ChaptersResponse.self, from: data) {
            return response.chapters
        }
        return try? decoder.decode([ChapterEntry].self, from: data)
    }

    static func makeChapters(from entries: [ChapterEntry]) -> [Chapter] {
        entries
            .compactMap { entry -> Chapter? in
                guard let startTime = entry.startTime?.value, startTime >= 0 else { return nil }
                // `toc: false` marks a chapter the publisher does not want in
                // the table of contents — artwork or link changes rather than
                // a real segment. Storing it but showing it anyway defeats it.
                let toc = entry.toc?.value
                guard toc != false else { return nil }

                let title = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                return Chapter(
                    startTime: startTime,
                    title: (title?.isEmpty == false) ? title! : "Kapittel",
                    img: entry.img,
                    url: entry.url,
                    toc: toc,
                    endTime: entry.endTime?.value
                )
            }
            .sorted { $0.startTime < $1.startTime }
    }

    func clearCache() {
        cache.removeAll()
    }

    static func getCurrentChapter(_ chapters: [Chapter], at time: TimeInterval) -> Chapter? {
        guard !chapters.isEmpty else { return nil }
        for chapter in chapters.reversed() {
            if chapter.startTime <= time {
                return chapter
            }
        }
        return nil
    }
}

// MARK: - Decodable Types

private struct ChaptersResponse: Decodable {
    let version: String?
    let chapters: [ChapterEntry]
}

struct ChapterEntry: Decodable {
    let startTime: FlexibleDouble?
    let title: String?
    let img: String?
    let url: String?
    let toc: FlexibleBool?
    let endTime: FlexibleDouble?
}

/// Chapter times arrive as numbers per the spec, but some generators emit them
/// as JSON strings. A strict `Double` decode throws on those and takes the
/// whole chapter list down with it.
struct FlexibleDouble: Decodable {
    let value: Double?

    init(_ value: Double?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = Double(string)
        } else {
            value = nil
        }
    }
}

/// Same leniency for `toc`, which shows up as both a boolean and as 0/1.
struct FlexibleBool: Decodable {
    let value: Bool?

    init(_ value: Bool?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int != 0
        } else {
            value = nil
        }
    }
}

import Foundation

actor ChapterService: ChapterFetching {
    static let shared = ChapterService()

    private var cache = TTLCache<[Chapter]>(ttl: AppConstants.chapterCacheTTL, maxSize: AppConstants.chapterCacheMaxSize)
    private let decoder = JSONDecoder()

    func fetchChapters(from url: String) async -> [Chapter] {
        guard !url.isEmpty,
              let requestUrl = URL(string: url),
              requestUrl.scheme == "https" else { return [] }

        // Check cache
        if let cached = cache.value(for: url) {
            return cached
        }

        do {
            let (data, urlResponse) = try await URLSession.shared.data(from: requestUrl)
            guard let http = urlResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            let response = try decoder.decode(ChaptersResponse.self, from: data)

            let chapters = response.chapters
                .filter { $0.startTime != nil }
                .map { ch in
                    Chapter(
                        startTime: ch.startTime ?? 0,
                        title: ch.title ?? "Kapittel",
                        img: ch.img,
                        url: ch.url,
                        toc: ch.toc,
                        endTime: ch.endTime
                    )
                }
                .sorted { $0.startTime < $1.startTime }

            cache.insert(chapters, for: url)
            return chapters
        } catch {
            return []
        }
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

private struct ChaptersResponse: Decodable {
    let version: String?
    let chapters: [ChapterEntry]

    struct ChapterEntry: Decodable {
        let startTime: Double?
        let title: String?
        let img: String?
        let url: String?
        let toc: Bool?
        let endTime: Double?
    }
}

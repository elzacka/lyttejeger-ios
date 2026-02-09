import Foundation

actor ChapterService {
    static let shared = ChapterService()

    private var cache: [String: (chapters: [Chapter], timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = AppConstants.chapterCacheTTL

    func fetchChapters(from url: String) async -> [Chapter] {
        guard !url.isEmpty else { return [] }

        // Check cache
        if let cached = cache[url], Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.chapters
        }

        guard let requestUrl = URL(string: url) else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: requestUrl)
            let response = try JSONDecoder().decode(ChaptersResponse.self, from: data)

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

            cache[url] = (chapters, Date())

            // Trim cache
            if cache.count > AppConstants.chapterCacheMaxSize {
                let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
                for entry in sorted.prefix(cache.count - AppConstants.chapterCacheMaxSize) {
                    cache.removeValue(forKey: entry.key)
                }
            }

            return chapters
        } catch {
            return []
        }
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

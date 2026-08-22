import SwiftUI
import ImageIO

struct CachedAsyncImage: View {
    let url: String?
    let size: CGFloat

    @State private var uiImage: UIImage?
    @State private var isLoading = true
    @State private var hasFailed = false
    @Environment(\.displayScale) private var displayScale

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = AppConstants.imageCacheCountLimit
        cache.totalCostLimit = AppConstants.imageCacheMemoryLimit
        return cache
    }()

    // URLCache is stored separately so clearCache() can reach it.
    // URLSessionConfiguration is copied at URLSession init — mutating
    // imageSession.configuration.urlCache after init has no effect.
    private static let imageURLCache = URLCache(
        memoryCapacity: 20 * 1024 * 1024,
        diskCapacity: 100 * 1024 * 1024
    )

    private static let imageSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = imageURLCache
        return URLSession(configuration: config)
    }()

    static func clearCache() {
        cache.removeAllObjects()
        imageURLCache.removeAllCachedResponses()
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if hasFailed {
                placeholder
            } else if isLoading {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(Color.appMuted)
                    .overlay {
                        ProgressView()
                    }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: AppRadius.md))
        .accessibilityHidden(true)
        .task(id: url) {
            await loadImage()
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: AppRadius.md)
            .fill(Color.appMuted)
            .overlay {
                Image(systemName: "headphones")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(Color.appMutedForeground)
            }
    }

    private func loadImage() async {
        guard let urlString = url, !urlString.isEmpty else {
            uiImage = nil
            hasFailed = true
            isLoading = false
            return
        }

        // Cache key includes target size so different sizes don't share entries
        let targetPixels = size * displayScale
        let cacheKey = NSString(string: "\(urlString)@\(Int(targetPixels))")

        // Read before any `await`, and before touching the loading state: a
        // cached image then lands in the same turn as the task starts, instead
        // of flashing the spinner on every row that scrolls back into view.
        if let cached = Self.cache.object(forKey: cacheKey) {
            uiImage = cached
            hasFailed = false
            isLoading = false
            return
        }

        uiImage = nil
        hasFailed = false
        isLoading = true

        guard let imageUrl = URL(string: urlString), imageUrl.scheme == "https" else {
            isLoading = false
            hasFailed = true
            return
        }

        do {
            let (data, _) = try await Self.imageSession.data(from: imageUrl)
            if let image = await Self.prepared(from: data, targetPixels: targetPixels) {
                Self.cache.setObject(image, forKey: cacheKey, cost: Self.cost(of: image))
                uiImage = image
            } else {
                hasFailed = true
            }
        } catch {
            if !Task.isCancelled {
                hasFailed = true
            }
        }
        isLoading = false
    }

    /// Decoding is the expensive half of showing artwork, and it used to run
    /// on the main actor with the rest of `loadImage` — one full-size podcast
    /// cover per row, which is what made list scrolling stutter.
    private static func prepared(from data: Data, targetPixels: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            downsample(data, to: targetPixels)
        }.value
    }

    /// ImageIO decodes straight to the size actually needed. The previous
    /// version decoded the full bitmap — routinely 1400x1400 for a cover — and
    /// then redrew it into a 168pt thumbnail, paying for a full-resolution
    /// decode nothing ever displayed.
    nonisolated static func downsample(_ data: Data, to targetPixels: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        // ImageIO would happily scale a small image *up* to the target, which
        // the previous implementation never did — it costs memory and looks
        // worse than the original. Read the real pixel size first, which is a
        // header read rather than a decode, and never ask for more than that.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let pixelWidth = properties?[kCGImagePropertyPixelWidth] as? CGFloat ?? targetPixels
        let pixelHeight = properties?[kCGImagePropertyPixelHeight] as? CGFloat ?? targetPixels
        let ceiling = max(min(targetPixels, max(pixelWidth, pixelHeight)), 1)

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: ceiling
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            // Not something ImageIO recognises as an image.
            return nil
        }
        return UIImage(cgImage: thumbnail)
    }

    /// `totalCostLimit` counts whatever the caller reports, so inserting
    /// without a cost left the memory limit inert — only `countLimit` applied.
    private static func cost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 16) {
        CachedAsyncImage(url: nil, size: 56)
        CachedAsyncImage(url: nil, size: 120)
    }
    .padding()
    .background(Color.appBackground)
}
#endif

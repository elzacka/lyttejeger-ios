import SwiftUI

struct CachedAsyncImage: View {
    let url: String?
    let size: CGFloat

    @State private var uiImage: UIImage?
    @State private var isLoading = true
    @State private var hasFailed = false
    @Environment(\.displayScale) private var displayScale

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB (downscaled images)
        return cache
    }()

    private static let imageSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024
        )
        return URLSession(configuration: config)
    }()

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
            isLoading = false
            hasFailed = true
            return
        }

        // Cache key includes target size so different sizes don't share entries
        let targetPixels = size * displayScale
        let cacheKey = NSString(string: "\(urlString)@\(Int(targetPixels))")

        // Check memory cache
        if let cached = Self.cache.object(forKey: cacheKey) {
            uiImage = cached
            isLoading = false
            return
        }

        guard let imageUrl = URL(string: urlString) else {
            isLoading = false
            hasFailed = true
            return
        }

        do {
            let (data, _) = try await Self.imageSession.data(from: imageUrl)
            if let image = UIImage(data: data) {
                let downscaled = Self.downscale(image, to: targetPixels)
                Self.cache.setObject(downscaled, forKey: cacheKey)
                uiImage = downscaled
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

    private static func downscale(_ image: UIImage, to targetPixels: CGFloat) -> UIImage {
        let maxDimension = max(image.size.width, image.size.height)
        guard maxDimension > targetPixels else { return image }

        let scale = targetPixels / maxDimension
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
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

import ImageIO
import SwiftUI

@MainActor
final class ProfileImageStore {
    enum Kind: String, Hashable {
        case avatar, thumbnail

        var displayLifetime: TimeInterval { self == .avatar ? 300 : 60 }
    }

    struct Resource: Hashable {
        let url: URL
        let kind: Kind

        var key: NSString { "\(kind.rawValue):\(url.absoluteString)" as NSString }
    }

    enum FetchResult {
        case image(UIImage)
        case denied
        case unavailable
    }

    private final class Snapshot {
        let image: UIImage
        let expiry: Date

        init(image: UIImage, expiry: Date) {
            self.image = image
            self.expiry = expiry
        }
    }

    private let snapshots = NSCache<NSString, Snapshot>()
    private var requests: [Resource: Task<UIImage?, Never>] = [:]
    private let fetch: (URL) async -> FetchResult
    private let now: () -> Date

    init(fetch: @escaping (URL) async -> FetchResult = ProfileImageStore.fetchImage, now: @escaping () -> Date = Date.init) {
        self.fetch = fetch
        self.now = now
        snapshots.totalCostLimit = 16 * 1024 * 1024
        snapshots.countLimit = 48
    }

    func displayedImage(for resource: Resource) -> UIImage? {
        guard let snapshot = snapshots.object(forKey: resource.key) else { return nil }
        guard snapshot.expiry > now() else {
            snapshots.removeObject(forKey: resource.key)
            return nil
        }
        return snapshot.image
    }

    func load(_ resource: Resource) async -> UIImage? {
        // Avatar URLs change when the photo is replaced. Thumbnails still check visibility on each visit.
        if resource.kind == .avatar, let current = displayedImage(for: resource) { return current }
        if let pending = requests[resource] { return await pending.value }

        let request = Task { [weak self, fetch] () -> UIImage? in
            let result = await fetch(resource.url)
            guard let self, !Task.isCancelled else { return nil }
            requests[resource] = nil
            switch result {
            case let .image(image):
                let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 1
                let snapshot = Snapshot(image: image, expiry: now().addingTimeInterval(resource.kind.displayLifetime))
                snapshots.setObject(snapshot, forKey: resource.key, cost: cost)
                return image
            case .denied:
                snapshots.removeObject(forKey: resource.key)
                return nil
            case .unavailable:
                return displayedImage(for: resource)
            }
        }
        requests[resource] = request
        return await request.value
    }

    func discard(_ resource: Resource) {
        requests.removeValue(forKey: resource)?.cancel()
        snapshots.removeObject(forKey: resource.key)
    }

    func clear() {
        requests.values.forEach { $0.cancel() }
        requests.removeAll()
        snapshots.removeAllObjects()
    }

    nonisolated private static func fetchImage(_ url: URL) async -> FetchResult {
        do {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .unavailable }
            if [401, 403, 404, 410].contains(http.statusCode) { return .denied }
            guard (200..<300).contains(http.statusCode),
                  let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: 600,
                  ] as CFDictionary) else { return .unavailable }
            return .image(UIImage(cgImage: image))
        } catch {
            return .unavailable
        }
    }
}

private struct ProfileImageStoreKey: EnvironmentKey {
    static let defaultValue: ProfileImageStore? = nil
}

extension EnvironmentValues {
    var profileImageStore: ProfileImageStore? {
        get { self[ProfileImageStoreKey.self] }
        set { self[ProfileImageStoreKey.self] = newValue }
    }
}

struct ProfileImage<Content: View>: View {
    @Environment(\.profileImageStore) private var store
    @State private var resolved: (resource: ProfileImageStore.Resource, image: UIImage?)?
    let resource: ProfileImageStore.Resource
    @ViewBuilder let content: (Image) -> Content

    var body: some View {
        if let store {
            let image = resolved?.resource == resource ? resolved?.image : store.displayedImage(for: resource)
            Group {
                if let image { content(Image(uiImage: image)) }
                else { Color.clear }
            }
            .task(id: resource) {
                let loaded = await store.load(resource)
                guard !Task.isCancelled else { return }
                resolved = (resource, loaded)
            }
        } else {
            AsyncImage(url: resource.url, content: content, placeholder: { Color.clear })
        }
    }
}

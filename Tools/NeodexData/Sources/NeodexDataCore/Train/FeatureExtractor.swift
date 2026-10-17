import Foundation
import Vision

/// Turns images into Apple's 768-value scene-print feature vectors (Vision's
/// `GenerateImageFeaturePrintRequest`, the same features the app computes on device), caching each
/// vector on disk so a second run only extracts what changed.
struct FeatureExtractor {
    static let dimension = 768
    static let version = "scene-print-2"

    let cacheDirectory: URL
    var concurrency = 6

    private var featureDirectory: URL { cacheDirectory.appendingPathComponent("features-\(Self.version)") }

    /// Feature vectors for `urls`, in order; `nil` where an image couldn't be read.
    func features(for urls: [URL], log: Pipeline.Log) async throws -> [[Float]?] {
        try FileManager.default.createDirectory(at: featureDirectory, withIntermediateDirectories: true)
        var results = [[Float]?](repeating: nil, count: urls.count)
        var extracted = 0
        var cached = 0
        try await withThrowingTaskGroup(of: (Int, [Float]?, Bool).self) { group in
            var next = 0
            func enqueue() {
                let index = next
                next += 1
                let url = urls[index]
                let cacheURL = featureDirectory.appendingPathComponent(cacheName(for: url))
                group.addTask {
                    if let data = try? Data(contentsOf: cacheURL), data.count == Self.dimension * MemoryLayout<Float>.size {
                        return (index, data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }, true)
                    }
                    var request = GenerateImageFeaturePrintRequest()
                    request.cropAndScaleAction = .scaleToFit
                    guard let observation = try? await request.perform(on: url), observation.elementCount == Self.dimension else {
                        return (index, nil, false)
                    }
                    let vector = observation.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
                    try? Data(bytes: vector, count: vector.count * MemoryLayout<Float>.size).write(to: cacheURL, options: .atomic)
                    return (index, vector, false)
                }
            }
            while next < min(concurrency, urls.count) { enqueue() }
            while let (index, vector, wasCached) = try await group.next() {
                results[index] = vector
                if wasCached { cached += 1 } else { extracted += 1 }
                let done = cached + extracted
                if done % 10_000 == 0 { log("  \(done)/\(urls.count) feature vectors") }
                if next < urls.count { enqueue() }
            }
        }
        log("  \(extracted) feature vectors extracted, \(cached) from cache, \(results.filter { $0 == nil }.count) unreadable")
        return results
    }

    private func cacheName(for url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return Fetcher.stableHash(url.path + "#\(size)") + ".f32"
    }
}

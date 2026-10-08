import Foundation

/// Downloads files with an on-disk cache so repeated runs are fast and offline-friendly.
actor Fetcher {
    enum FetchError: Error, LocalizedError {
        case badStatus(Int, URL)
        case invalidResponse(URL)

        var errorDescription: String? {
            switch self {
            case .badStatus(let code, let url): "HTTP \(code) for \(url)"
            case .invalidResponse(let url): "Invalid response for \(url)"
            }
        }
    }

    let cacheDirectory: URL
    private let session: URLSession
    private var inFlight: [URL: Task<Data?, Error>] = [:]
    private(set) var downloads = 0
    private(set) var cacheHits = 0

    init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 8
        configuration.timeoutIntervalForRequest = 60
        configuration.httpAdditionalHeaders = ["User-Agent": "Neodex data pipeline (https://github.com/EthanMarshall/Neodex)"]
        session = URLSession(configuration: configuration)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Returns the bytes at `url`, or `nil` when the server returns 404 and `allowNotFound` is set.
    func data(for url: URL, allowNotFound: Bool = false) async throws -> Data? {
        if let existing = inFlight[url] { return try await existing.value }
        let task = Task<Data?, Error> { [cacheDirectory, session] in
            let cacheURL = Fetcher.cacheURL(for: url, in: cacheDirectory)
            let notFoundMarker = cacheURL.appendingPathExtension("404")
            if FileManager.default.fileExists(atPath: notFoundMarker.path) {
                if allowNotFound { return nil }
                throw FetchError.badStatus(404, url)
            }
            if let cached = try? Data(contentsOf: cacheURL) { return cached }

            var lastError: Error?
            for attempt in 1...3 {
                do {
                    let (data, response) = try await session.data(from: url)
                    guard let http = response as? HTTPURLResponse else { throw FetchError.invalidResponse(url) }
                    switch http.statusCode {
                    case 200..<300:
                        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try data.write(to: cacheURL, options: .atomic)
                        return data
                    case 404:
                        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try Data().write(to: notFoundMarker)
                        if allowNotFound { return nil }
                        throw FetchError.badStatus(404, url)
                    default:
                        throw FetchError.badStatus(http.statusCode, url)
                    }
                } catch let error as FetchError {
                    throw error
                } catch {
                    lastError = error
                    try? await Task.sleep(for: .seconds(Double(attempt) * 1.5))
                }
            }
            throw lastError ?? FetchError.invalidResponse(url)
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let wasCached = FileManager.default.fileExists(atPath: Fetcher.cacheURL(for: url, in: cacheDirectory).path)
        let result = try await task.value
        if wasCached { cacheHits += 1 } else { downloads += 1 }
        return result
    }

    func string(for url: URL) async throws -> String {
        guard let data = try await data(for: url) else { throw FetchError.badStatus(404, url) }
        return String(decoding: data, as: UTF8.self)
    }

    nonisolated static func cacheURL(for url: URL, in directory: URL) -> URL {
        let host = url.host ?? "unknown"
        let path = url.path.split(separator: "/").map(String.init).joined(separator: "/")
        return directory.appendingPathComponent(host).appendingPathComponent(path.isEmpty ? "index" : path)
    }
}

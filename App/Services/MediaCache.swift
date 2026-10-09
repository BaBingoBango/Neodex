import CryptoKit
import Foundation

/// URLs for the media Pokémon Showdown serves that isn't bundled with the app.
nonisolated enum ShowdownMedia {
    static let base = URL(string: "https://play.pokemonshowdown.com/")!

    /// The animated Gen 5-style battle sprite, e.g. `sprites/ani/garchomp.gif`.
    static func animatedSprite(_ stem: String, shiny: Bool) -> URL {
        base.appendingPathComponent("sprites/\(shiny ? "ani-shiny" : "ani")/\(stem).gif")
    }

    /// The static shiny sprite, used when a Pokémon has no animated one.
    static func staticShinySprite(_ stem: String) -> URL {
        base.appendingPathComponent("sprites/gen5-shiny/\(stem).png")
    }

    /// The Pokémon's cry as MP3.
    static func cry(_ stem: String) -> URL {
        base.appendingPathComponent("audio/cries/\(stem).mp3")
    }
}

/// Downloads Showdown media once and keeps it in the Caches directory.
actor MediaCache {
    static let shared = MediaCache()

    enum MediaError: Error {
        case notFound
        case badResponse(Int)
    }

    private let session: URLSession
    private let directory: URL
    private var inFlight: [URL: Task<Data, Error>] = [:]
    private var knownMisses: Set<URL> = []

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("ShowdownMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// The media at `url`, from disk when it has been fetched before.
    func data(for url: URL) async throws -> Data {
        if knownMisses.contains(url) { throw MediaError.notFound }
        let file = fileURL(for: url)
        if let data = try? Data(contentsOf: file) { return data }
        if let task = inFlight[url] { return try await task.value }

        let task = Task<Data, Error> { [session] in
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw MediaError.badResponse(0) }
            switch http.statusCode {
            case 200..<300: return data
            case 404: throw MediaError.notFound
            default: throw MediaError.badResponse(http.statusCode)
            }
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        do {
            let data = try await task.value
            try? data.write(to: file, options: .atomic)
            return data
        } catch MediaError.notFound {
            knownMisses.insert(url)
            throw MediaError.notFound
        }
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + "-" + url.lastPathComponent)
    }
}

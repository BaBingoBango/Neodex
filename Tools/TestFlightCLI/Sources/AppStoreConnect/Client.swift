import Foundation

/// A minimal App Store Connect API client: signed GETs, JSON:API decoding and pagination.
public struct Client: Sendable {
    public static let baseURL = URL(string: "https://api.appstoreconnect.apple.com")!

    public let credentials: Credentials

    public init(credentials: Credentials) {
        self.credentials = credentials
    }

    public func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: Self.baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw ASCError.unexpected("Couldn't build a URL for \(path).") }
        return try await get(url)
    }

    /// Fetches an absolute API URL, such as a `links.next` page. The token only ever goes to Apple's API host.
    public func get<T: Decodable & Sendable>(_ url: URL) async throws -> T {
        guard url.scheme == "https", url.host() == Self.baseURL.host() else {
            throw ASCError.unexpected("Refusing to send App Store Connect credentials to \(url.host() ?? url.absoluteString).")
        }
        let token = try AuthToken.make(for: credentials)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ASCError.http(status: status, messages: ErrorDocument.messages(in: data))
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ASCError.unexpected("App Store Connect sent a response this tool couldn't read: \(error)")
        }
    }

    /// Downloads a file Apple links to, such as a screenshot. The links are pre-signed, so no token is sent.
    public func download(_ url: URL) async throws -> (data: Data, fileExtension: String) {
        guard url.scheme == "https" else {
            throw ASCError.unexpected("Refusing a download that isn't HTTPS: \(url.host() ?? url.absoluteString).")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ASCError.http(status: status, messages: ["The download failed; the link may have expired."])
        }
        return (data, Self.fileExtension(mimeType: response.mimeType, url: url))
    }

    static func fileExtension(mimeType: String?, url: URL) -> String {
        switch mimeType {
        case "image/png": return "png"
        case "image/jpeg", "image/jpg": return "jpg"
        case "image/heic": return "heic"
        default:
            let fromURL = url.pathExtension.lowercased()
            return fromURL.isEmpty ? "jpg" : fromURL
        }
    }
}

public struct App: Sendable {
    public let id: String
    public let name: String
    public let bundleID: String
}

public struct BuildSummary: Sendable {
    public let id: String
    public let number: String?
    public let marketingVersion: String?
    public let platform: String?
    public let processingState: String?
    public let uploaded: Date?
    public let expires: Date?
    public let expired: Bool
}

extension Client {
    /// The app with exactly this bundle ID.
    public func app(bundleID: String) async throws -> App {
        let response: ListResponse<AppAttributes> = try await get("/v1/apps", query: [
            URLQueryItem(name: "filter[bundleId]", value: bundleID),
            URLQueryItem(name: "fields[apps]", value: "name,bundleId"),
        ])
        guard let match = response.data.first(where: { $0.attributes?.bundleId == bundleID }) else {
            throw ASCError.appNotFound(bundleID)
        }
        return App(id: match.id, name: match.attributes?.name ?? bundleID, bundleID: bundleID)
    }

    /// The newest uploads, with their marketing version, platform and processing state.
    public func builds(appID: String, limit: Int) async throws -> [BuildSummary] {
        let response: ListResponse<BuildAttributes> = try await get("/v1/builds", query: [
            URLQueryItem(name: "filter[app]", value: appID),
            URLQueryItem(name: "sort", value: "-uploadedDate"),
            URLQueryItem(name: "limit", value: String(min(max(limit, 1), 200))),
            URLQueryItem(name: "include", value: "preReleaseVersion"),
            URLQueryItem(name: "fields[builds]", value: "version,uploadedDate,expirationDate,expired,processingState,preReleaseVersion"),
            URLQueryItem(name: "fields[preReleaseVersions]", value: "version,platform"),
        ])
        return response.data.map { resource in
            let release = response.included(resource.relationships?["preReleaseVersion"]?.data)
            return BuildSummary(id: resource.id,
                                number: resource.attributes?.version,
                                marketingVersion: release?.attributes?.version,
                                platform: release?.attributes?.platform,
                                processingState: resource.attributes?.processingState,
                                uploaded: ASCDate.parse(resource.attributes?.uploadedDate),
                                expires: ASCDate.parse(resource.attributes?.expirationDate),
                                expired: resource.attributes?.expired ?? false)
        }
    }
}

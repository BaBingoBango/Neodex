import Foundation

// The slice of App Store Connect's JSON:API shapes this tool reads. Every attribute is optional:
// Apple adds fields over time, and a missing one should never break a fetch.

public struct Resource<Attributes: Decodable & Sendable>: Decodable, Sendable {
    public let type: String
    public let id: String
    public let attributes: Attributes?
    public let relationships: [String: Relationship]?
}

/// A to-one relationship. Its linkage appears only when the request `include`d it.
public struct Relationship: Decodable, Sendable {
    public let data: Linkage?

    enum CodingKeys: String, CodingKey { case data }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try? container.decodeIfPresent(Linkage.self, forKey: .data)
    }
}

public struct Linkage: Decodable, Sendable, Hashable {
    public let type: String
    public let id: String
}

/// A related resource sent alongside the main data: a build, a pre-release version or a tester.
public struct IncludedResource: Decodable, Sendable {
    public let type: String
    public let id: String
    public let attributes: Attributes?

    public struct Attributes: Decodable, Sendable {
        /// A build's number, or a pre-release version's marketing version.
        public let version: String?
        public let platform: String?
        public let firstName: String?
        public let lastName: String?
        public let email: String?
    }
}

public struct ListResponse<Attributes: Decodable & Sendable>: Decodable, Sendable {
    public let data: [Resource<Attributes>]
    public let included: [IncludedResource]?
    public let links: Links?
    public let meta: Meta?

    public struct Links: Decodable, Sendable {
        public let next: URL?
    }

    public struct Meta: Decodable, Sendable {
        public let paging: Paging?

        public struct Paging: Decodable, Sendable {
            public let total: Int?
            public let limit: Int?
        }
    }

    public func included(_ linkage: Linkage?) -> IncludedResource? {
        guard let linkage else { return nil }
        return included?.first { $0.type == linkage.type && $0.id == linkage.id }
    }
}

public struct SingleResponse<Attributes: Decodable & Sendable>: Decodable, Sendable {
    public let data: Resource<Attributes>
}

public struct AppAttributes: Decodable, Sendable {
    public let name: String?
    public let bundleId: String?
}

/// A tester's screenshot or crash report. The two share every field except the screenshots.
public struct FeedbackAttributes: Decodable, Sendable {
    public let createdDate: String?
    public let comment: String?
    public let email: String?
    public let deviceModel: String?
    public let osVersion: String?
    public let locale: String?
    public let timeZone: String?
    public let architecture: String?
    public let connectionType: String?
    public let pairedAppleWatch: String?
    public let appUptimeInMilliseconds: Int?
    public let diskBytesAvailable: Int?
    public let diskBytesTotal: Int?
    public let batteryPercentage: Int?
    public let screenWidthInPoints: Int?
    public let screenHeightInPoints: Int?
    public let appPlatform: String?
    public let devicePlatform: String?
    public let deviceFamily: String?
    public let buildBundleId: String?
    public let screenshots: [ScreenshotImage]?

    /// A pre-signed link to one screenshot, valid until `expirationDate`.
    public struct ScreenshotImage: Decodable, Sendable {
        public let url: URL?
        public let width: Int?
        public let height: Int?
        public let expirationDate: String?
    }
}

public struct CrashLogAttributes: Decodable, Sendable {
    public let logText: String?
}

public struct BuildAttributes: Decodable, Sendable {
    public let version: String?
    public let uploadedDate: String?
    public let expirationDate: String?
    public let expired: Bool?
    public let processingState: String?
}

/// App Store Connect's error body: `{"errors": [{"status", "code", "title", "detail"}]}`.
struct ErrorDocument: Decodable {
    struct Entry: Decodable {
        let status: String?
        let code: String?
        let title: String?
        let detail: String?
    }

    let errors: [Entry]

    static func messages(in data: Data) -> [String] {
        guard let document = try? JSONDecoder().decode(ErrorDocument.self, from: data) else { return [] }
        return document.errors
            .map { [$0.title, $0.detail].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " ") }
            .filter { !$0.isEmpty }
    }
}

/// App Store Connect's timestamps, with or without fractional seconds.
public enum ASCDate {
    public static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

/// Human names for App Store Connect's platform and device-family codes.
public enum Platform {
    public static func name(_ raw: String?) -> String? {
        guard let raw else { return nil }
        switch raw {
        case "IOS": return "iOS"
        case "MAC_OS": return "macOS"
        case "TV_OS": return "tvOS"
        case "VISION_OS": return "visionOS"
        case "WATCH_OS": return "watchOS"
        default: return raw
        }
    }

    public static func family(_ raw: String?) -> String? {
        guard let raw else { return nil }
        switch raw {
        case "IPHONE": return "iPhone"
        case "IPAD": return "iPad"
        case "MAC": return "Mac"
        case "APPLE_TV": return "Apple TV"
        case "APPLE_WATCH": return "Apple Watch"
        case "APPLE_VISION_PRO", "VISION": return "Apple Vision Pro"
        default: return raw
        }
    }
}

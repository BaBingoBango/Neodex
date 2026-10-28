import Foundation

/// One TestFlight report, screenshot or crash, with its build number and tester resolved.
public struct FeedbackItem: Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case screenshot, crash

        var resourcePath: String { self == .screenshot ? "betaFeedbackScreenshotSubmissions" : "betaFeedbackCrashSubmissions" }

        public var noun: String { self == .screenshot ? "screenshot report" : "crash report" }
    }

    public let kind: Kind
    public let id: String
    public let attributes: FeedbackAttributes
    public let buildNumber: String?
    public let tester: String?

    public var createdDate: Date? { ASCDate.parse(attributes.createdDate) }

    public var comment: String? { attributes.comment.nonEmpty }

    /// "iPhone18,2 · iOS 27.1", falling back to the device family when the model is missing.
    public var deviceSummary: String {
        let device = attributes.deviceModel.nonEmpty ?? Platform.family(attributes.deviceFamily)
        let system = [Platform.name(attributes.devicePlatform), attributes.osVersion].compactMap(\.self).joined(separator: " ")
        return [device, system.isEmpty ? nil : system].compactMap(\.self).joined(separator: " · ")
    }

    /// The report as a small Markdown page, saved beside its screenshots or crash log.
    public func markdown(files: [String]) -> String {
        var lines = ["# " + (kind == .screenshot ? "Screenshot feedback" : "Crash report")
                     + (createdDate.map { " · " + $0.formatted(date: .abbreviated, time: .shortened) } ?? ""), ""]
        if let comment {
            lines += comment.split(separator: "\n", omittingEmptySubsequences: false).map { "> " + $0 }
            lines.append("")
        }
        func add(_ label: String, _ value: String?) {
            if let value, !value.isEmpty { lines.append("- \(label): \(value)") }
        }
        add("Build", buildNumber.map { "build \($0)" + (Platform.name(attributes.appPlatform).map { " (\($0))" } ?? "") })
        add("Device", deviceSummary)
        add("Tester", tester)
        add("Locale", [attributes.locale, attributes.timeZone].compactMap(\.self).joined(separator: " · "))
        add("Connection", attributes.connectionType)
        add("Battery", attributes.batteryPercentage.map { "\($0)%" })
        add("App uptime", attributes.appUptimeInMilliseconds.map(Self.duration))
        if let width = attributes.screenWidthInPoints, let height = attributes.screenHeightInPoints {
            add("Screen", "\(width) × \(height) pt")
        }
        add("Paired watch", attributes.pairedAppleWatch)
        if let free = attributes.diskBytesAvailable, let total = attributes.diskBytesTotal {
            add("Disk", "\(Int64(free).formatted(.byteCount(style: .file))) free of \(Int64(total).formatted(.byteCount(style: .file)))")
        }
        add("Files", files.joined(separator: ", "))
        add("ID", id)
        return lines.joined(separator: "\n") + "\n"
    }

    static func duration(_ milliseconds: Int) -> String {
        let seconds = milliseconds / 1000
        if seconds < 60 { return "\(seconds) s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min \(seconds % 60) s" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }
}

extension Client {
    /// The newest reports first, following pages until `limit` are collected.
    public func feedback(_ kind: FeedbackItem.Kind, appID: String, limit: Int) async throws -> (items: [FeedbackItem], total: Int?) {
        let pageSize = min(max(limit, 1), 200)
        var page: ListResponse<FeedbackAttributes> = try await get("/v1/apps/\(appID)/\(kind.resourcePath)", query: [
            URLQueryItem(name: "include", value: "build,tester"),
            URLQueryItem(name: "sort", value: "-createdDate"),
            URLQueryItem(name: "limit", value: String(pageSize)),
            URLQueryItem(name: "fields[builds]", value: "version"),
            URLQueryItem(name: "fields[betaTesters]", value: "firstName,lastName"),
        ])
        let total = page.meta?.paging?.total
        var items: [FeedbackItem] = []
        while true {
            items += Self.items(kind, in: page)
            guard items.count < limit, let next = page.links?.next else { break }
            page = try await get(next)
        }
        return (Array(items.prefix(limit)), total)
    }

    /// How many reports TestFlight holds, without fetching them.
    public func feedbackTotal(_ kind: FeedbackItem.Kind, appID: String) async throws -> Int {
        let page: ListResponse<FeedbackAttributes> = try await get("/v1/apps/\(appID)/\(kind.resourcePath)", query: [
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "fields[\(kind.resourcePath)]", value: "createdDate"),
        ])
        if let total = page.meta?.paging?.total { return total }
        return try await feedback(kind, appID: appID, limit: 200).items.count
    }

    /// The crash log a tester's device attached to a crash report.
    public func crashLog(submissionID: String) async throws -> String? {
        let response: SingleResponse<CrashLogAttributes> = try await get("/v1/betaFeedbackCrashSubmissions/\(submissionID)/crashLog")
        return response.data.attributes?.logText
    }

    static func items(_ kind: FeedbackItem.Kind, in page: ListResponse<FeedbackAttributes>) -> [FeedbackItem] {
        page.data.compactMap { resource in
            guard let attributes = resource.attributes else { return nil }
            let build = page.included(resource.relationships?["build"]?.data)
            let tester = page.included(resource.relationships?["tester"]?.data)
            let name = [tester?.attributes?.firstName, tester?.attributes?.lastName].compactMap(\.self).joined(separator: " ")
            return FeedbackItem(kind: kind, id: resource.id, attributes: attributes,
                                buildNumber: build?.attributes?.version,
                                tester: name.isEmpty ? attributes.email : name)
        }
    }
}

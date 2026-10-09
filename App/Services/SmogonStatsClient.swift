import Foundation
import NeodexKit

/// Which month, format and rating cutoff of Smogon's usage statistics to show.
nonisolated struct UsageSelection: Hashable, Sendable {
    var month: String
    var format: String
    var rating: Int

    var rankingsURL: URL { SmogonStatsClient.base.appendingPathComponent("\(month)/\(format)-\(rating).txt") }
    var chaosURL: URL { SmogonStatsClient.base.appendingPathComponent("\(month)/chaos/\(format)-\(rating).json") }
}

/// One month of a Pokémon's usage in a format.
nonisolated struct UsageTrendPoint: Identifiable, Hashable, Sendable {
    var month: String
    var usagePercent: Double
    var rank: Int?

    var id: String { month }

    /// The first day of the month, for charting.
    var date: Date {
        let parts = month.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents()
        components.year = parts.first
        components.month = parts.count > 1 ? parts[1] : 1
        components.day = 1
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }
}

/// Fetches and caches Smogon's monthly usage statistics.
actor SmogonStatsClient {
    static let shared = SmogonStatsClient()
    static let base = URL(string: "https://www.smogon.com/stats/")!

    enum ClientError: LocalizedError {
        case notFound
        case badResponse(Int)
        case noData

        var errorDescription: String? {
            switch self {
            case .notFound: "Smogon has no usage data for that format and month."
            case .badResponse(let code): "Smogon returned an unexpected response (\(code))."
            case .noData: "No usage data was returned."
            }
        }
    }

    private let session: URLSession
    private var monthsCache: [String]?
    private var formatsCache: [String: [UsageFormat]] = [:]
    private var rankingsCache: [UsageSelection: UsageRankingsReport] = [:]
    private var chaosCache: [UsageSelection: UsageChaosReport] = [:]

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 32_000_000, diskCapacity: 256_000_000)
        configuration.timeoutIntervalForRequest = 45
        session = URLSession(configuration: configuration)
    }

    /// Months with published statistics, newest first.
    func months() async throws -> [String] {
        if let monthsCache { return monthsCache }
        let html = try await string(Self.base, policy: .reloadRevalidatingCacheData)
        let months = UsageTextParser.parseMonths(fromIndexHTML: html).filter { !$0.contains("DLC") }
        guard !months.isEmpty else { throw ClientError.noData }
        monthsCache = months
        return months
    }

    /// Formats available for a month, with their rating cutoffs.
    func formats(for month: String) async throws -> [UsageFormat] {
        if let cached = formatsCache[month] { return cached }
        let html = try await string(Self.base.appendingPathComponent("\(month)/chaos/"), policy: .returnCacheDataElseLoad)
        let formats = UsageTextParser.parseFormats(fromDirectoryHTML: html)
        guard !formats.isEmpty else { throw ClientError.noData }
        formatsCache[month] = formats
        return formats
    }

    func rankings(for selection: UsageSelection) async throws -> UsageRankingsReport {
        if let cached = rankingsCache[selection] { return cached }
        let text = try await string(selection.rankingsURL, policy: .returnCacheDataElseLoad)
        let report = UsageTextParser.parseRankings(text)
        guard !report.rankings.isEmpty else { throw ClientError.noData }
        rankingsCache[selection] = report
        return report
    }

    func chaos(for selection: UsageSelection) async throws -> UsageChaosReport {
        if let cached = chaosCache[selection] { return cached }
        let data = try await data(selection.chaosURL, policy: .returnCacheDataElseLoad)
        let report = try UsageChaosReport.decode(data)
        chaosCache[selection] = report
        return report
    }

    /// A Pokémon's usage across the most recent months of a format, oldest first.
    /// Months in which the format or rating cutoff didn't exist are skipped.
    func usageTrend(for name: String, format: String, rating: Int, months limit: Int) async -> [UsageTrendPoint] {
        guard let months = try? await months() else { return [] }
        let key = ShowdownID.make(name)
        return await withTaskGroup(of: UsageTrendPoint?.self) { group in
            for month in months.prefix(limit) {
                group.addTask {
                    let selection = UsageSelection(month: month, format: format, rating: rating)
                    guard let report = try? await self.rankings(for: selection) else { return nil }
                    guard let ranking = report.rankings.first(where: { ShowdownID.make($0.name) == key }) else {
                        return UsageTrendPoint(month: month, usagePercent: 0, rank: nil)
                    }
                    return UsageTrendPoint(month: month, usagePercent: ranking.usagePercent, rank: ranking.rank)
                }
            }
            var points: [UsageTrendPoint] = []
            for await point in group {
                if let point { points.append(point) }
            }
            return points.sorted { $0.month < $1.month }
        }
    }

    private func string(_ url: URL, policy: URLRequest.CachePolicy) async throws -> String {
        String(decoding: try await data(url, policy: policy), as: UTF8.self)
    }

    private func data(_ url: URL, policy: URLRequest.CachePolicy) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = policy
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.noData }
        switch http.statusCode {
        case 200..<300: return data
        case 404: throw ClientError.notFound
        default: throw ClientError.badResponse(http.statusCode)
        }
    }
}

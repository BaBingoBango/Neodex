//
//  MetaStore.swift
//  Scope Lens
//
//  Phase 3, m11-C (pilot-requested): runtime meta refresh. Regulations
//  rotate, so the bundled Reg M-B S3 snapshot (crawled 2026-07-02) will go
//  stale; this manager owns an Application Support cache, the polite
//  Pikalytics crawl (Swift port of Tools/ScopeLensEngine/fetch-meta.js), and CURRENT-
//  regulation discovery from the site's format selector. Engines hot-swap
//  snapshots through ScopeEngine.setMeta — the seam m3 built exactly for
//  this day.
//
//  The committed repo snapshot (Tools/ScopeLensEngine/data/meta-regmbs3.json) is NEVER
//  touched: every CLI harness and the MCP parity test pin to it, so a
//  refresh can't break verify-all. Only the running app prefers the cache.
//
//  ToS posture (acknowledged since m3, spec §6): Pikalytics is fetched
//  politely — 2 concurrent requests, ~200ms spacing per worker, a hard
//  page cap, an identifying User-Agent — and ONLY on explicit pilot action
//  (the Settings "Refresh" button); never on a timer.
//
//  APP-ONLY file: uses Bundle.module; never compiled into Diagnostics.
//

import Foundation
import Combine

/// Sidecar metadata for a cached snapshot. The payload file itself stays
/// in the engine's raw {slug: profile} shape — setMeta and the MCP server
/// understand exactly that, no envelope. Top-level nonisolated: nesting it
/// in the MainActor class isolated its Codable conformance (the m9/m11
/// shared-file lesson striking a third time, this round on conformances).
nonisolated struct MetaSnapshotInfo: Codable {
    var regulation: String       // "Reg M-B S3"
    var formatSlug: String       // "battledataregmbs3"
    var fetchedAt: Date
    var speciesCount: Int
}

@MainActor
final class MetaStore: ObservableObject {

    static let shared = MetaStore()

    /// Posted after a successful refresh writes the cache. The live tracker
    /// hot-swaps the engine's snapshot (setMeta) and recomputes.
    nonisolated static let metaChanged = Notification.Name("ScopeLensMetaChanged")

    /// What the bundled fallback is, for the UI when no cache exists.
    nonisolated static let bundledRegulation = "Reg M-B S3"
    nonisolated static let bundledCrawlDate = "2026-07-02"

    @Published private(set) var info: MetaSnapshotInfo?
    @Published private(set) var isRefreshing = false
    @Published private(set) var progressLine: String?
    @Published private(set) var lastError: String?

    private init() {
        info = Self.loadInfo()
    }

    // MARK: Cache files (Application Support, beside team.json)

    nonisolated private static var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("meta-current.json")
    }
    nonisolated private static var infoURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("meta-info.json")
    }

    nonisolated private static func loadInfo() -> MetaSnapshotInfo? {
        guard let data = try? Data(contentsOf: infoURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MetaSnapshotInfo.self, from: data)
    }

    /// The cached snapshot payload, when present AND structurally sane
    /// (a real profile dict, not a truncated write). Engine boot applies
    /// this over the bundled snapshot; nonisolated so the engine actor can
    /// read it directly.
    nonisolated static func cachedMetaData() -> Data? {
        guard let data = try? Data(contentsOf: cacheURL),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              dict.count >= 40 else { return nil }
        return data
    }

    // MARK: Refresh (the pilot's Settings button)

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        progressLine = "Discovering the current ranked format…"

        // A @MainActor task: awaited work (the crawl) still runs off-actor
        // in MetaFetcher's nonisolated functions; only the continuations
        // and property writes land here — no MainActor.run hops, no
        // captured-weak-var-in-concurrent-code warnings.
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let format = try await MetaFetcher.discoverCurrentFormat()
                self.progressLine = "Crawling \(format.regulation) usage data…"
                let result = try await MetaFetcher.crawl(formatSlug: format.slug) { fetched, queued, profiles in
                    Task { @MainActor in
                        MetaStore.shared.progressLine =
                            "Fetched \(fetched) pages · \(queued) queued · \(profiles) profiles"
                    }
                }
                // Refuse a suspiciously thin crawl — a layout change must
                // never clobber a good cache with a near-empty snapshot.
                guard result.profiles.count >= 40 else {
                    throw MetaFetcher.FetchError(
                        message: "Crawl found only \(result.profiles.count) profiles — Pikalytics layout may have changed; keeping the current snapshot.")
                }
                let payload = try JSONSerialization.data(
                    withJSONObject: result.profiles, options: [.sortedKeys])
                let info = MetaSnapshotInfo(regulation: format.regulation,
                                            formatSlug: format.slug,
                                            fetchedAt: Date(),
                                            speciesCount: result.profiles.count)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let infoData = try encoder.encode(info)
                try payload.write(to: Self.cacheURL, options: .atomic)
                try infoData.write(to: Self.infoURL, options: .atomic)

                self.info = info
                self.isRefreshing = false
                self.progressLine = nil
                NotificationCenter.default.post(name: Self.metaChanged, object: nil)
            } catch {
                self.isRefreshing = false
                self.progressLine = nil
                self.lastError = (error as? MetaFetcher.FetchError)?.message
                    ?? error.localizedDescription
            }
        }
    }

    /// Drop the cache and fall back to the bundled snapshot.
    func revertToBundled() {
        try? FileManager.default.removeItem(at: Self.cacheURL)
        try? FileManager.default.removeItem(at: Self.infoURL)
        info = nil
        lastError = nil
        NotificationCenter.default.post(name: Self.metaChanged, object: nil)
    }

    /// Days since the active snapshot was crawled (bundled uses its
    /// committed crawl date). Drives the staleness badge.
    var snapshotAgeDays: Int {
        let fetched: Date
        if let info {
            fetched = info.fetchedAt
        } else {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            fetched = f.date(from: Self.bundledCrawlDate) ?? .distantPast
        }
        return max(0, Int(Date().timeIntervalSince(fetched) / 86_400))
    }
}

// MARK: - The crawl (Swift port of Tools/ScopeLensEngine/fetch-meta.js)

nonisolated enum MetaFetcher {

    struct FetchError: Error { let message: String }

    static let base = "https://www.pikalytics.com"
    static let cap = 400                 // fuse against runaway crawls
    static let concurrency = 2
    static let spacingNanos: UInt64 = 200_000_000   // 200ms per worker

    /// Same seed list as Tools/ScopeLensEngine/fetch-meta.js — a safety net under the
    /// index-page discovery (unranked seeds parse empty and are dropped).
    static let seeds = [
        "garchomp", "sinistcha", "basculegion", "whimsicott", "kingambit", "staraptor",
        "incineroar", "charizard", "raichu", "pelipper", "sneasler", "archaludon",
        "grimmsnarl", "sylveon", "swampert", "metagross", "farigiraf", "floette-eternal",
        "gholdengo", "aerodactyl", "venusaur", "rotom-wash", "dialga", "politoed",
        "sableye", "scizor", "falinks", "mawile", "ceruledge", "milotic",
        "dragonite", "typhlosion-hisui",
    ]

    static func get(_ url: String) async -> String {
        guard let u = URL(string: url) else { return "" }
        var request = URLRequest(url: u)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (ScopeLens meta snapshot)",
                         forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: Format discovery (regulations rotate — never hardcode the slug)

    /// The pokedex page's format selector lists every dataset; Champions
    /// RANKED data uses "battledata…" slugs (the Showdown sims don't), and
    /// the site marks the current one `selected`. Verified 2026-07-07:
    /// `<option value="battledataregmbs3-1760" selected>Pokemon Champions
    /// Regulation Set M-B S3 Ranked Battle Data</option>`.
    static func discoverCurrentFormat() async throws -> (slug: String, regulation: String) {
        let html = await get("\(base)/pokedex")
        guard !html.isEmpty else {
            throw FetchError(message: "Couldn't reach Pikalytics — check the connection.")
        }
        let pattern = #"<option value="(battledata[a-z0-9]+)-\d+"\s*(selected)?\s*>([^<]+)</option>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw FetchError(message: "internal: bad discovery pattern")
        }
        var options: [(slug: String, selected: Bool, label: String)] = []
        regex.enumerateMatches(in: html, range: NSRange(html.startIndex..., in: html)) { m, _, _ in
            guard let m,
                  let slugRange = Range(m.range(at: 1), in: html),
                  let labelRange = Range(m.range(at: 3), in: html) else { return }
            options.append((String(html[slugRange]),
                            m.range(at: 2).location != NSNotFound,
                            String(html[labelRange]).trimmingCharacters(in: .whitespaces)))
        }
        guard let pick = options.first(where: \.selected) ?? options.first else {
            throw FetchError(message: "No ranked battle-data format found on Pikalytics — the site layout may have changed; keeping the current snapshot.")
        }
        return (pick.slug, shortRegulation(from: pick.label, slug: pick.slug))
    }

    /// "Pokemon Champions Regulation Set M-B S3 Ranked Battle Data" → "Reg M-B S3".
    static func shortRegulation(from label: String, slug: String) -> String {
        if let regex = try? NSRegularExpression(pattern: #"Regulation Set (.+?) Ranked"#),
           let m = regex.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)),
           let r = Range(m.range(at: 1), in: label) {
            return "Reg \(label[r])"
        }
        return slug
    }

    // MARK: The BFS crawl (teammate-graph closure, as in fetch-meta.js)

    /// One species profile in the engine's shape.
    private static func parseProfile(_ html: String) -> [String: Any]? {
        func grab(_ pattern: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            guard let m = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let r = Range(m.range(at: 1), in: html) else { return nil }
            return String(html[r])
        }
        func list(_ text: String?) -> [String: Double] {
            guard let text else { return [:] }
            var out: [String: Double] = [:]
            guard let regex = try? NSRegularExpression(
                pattern: #"([A-Za-zÀ-ÿ0-9'’.: -]+?) \((\d+(?:\.\d+)?)%\)"#) else { return out }
            regex.enumerateMatches(in: text, range: NSRange(text.startIndex..., in: text)) { m, _, _ in
                guard let m,
                      let nameRange = Range(m.range(at: 1), in: text),
                      let pctRange = Range(m.range(at: 2), in: text),
                      let pct = Double(text[pctRange]) else { return }
                var name = String(text[nameRange]).trimmingCharacters(in: .whitespaces)
                if name.hasPrefix("and ") { name = String(name.dropFirst(4)) }
                out[name] = pct
            }
            return out
        }
        let moves = list(grab(#"top moves for [^"]*? are ([^"]*?)\. These"#))
        guard !moves.isEmpty else { return nil }   // unranked/404 — keep hasMeta honest
        var profile: [String: Any] = [
            "moves": moves,
            "items": list(grab(#"most popular items for [^"]*? are ([^"]*?)\. The best"#)),
            "abilities": list(grab(#"most common abilities for [^"]*? are ([^"]*?)\. The choice"#)),
        ]
        if let w = grab(#"has a (\d+(?:\.\d+)?)% winrate"#), let winrate = Double(w) {
            profile["winrate"] = winrate
        } else {
            profile["winrate"] = NSNull()
        }
        // m15-D parity with fetch-meta.js: spreads (Champions-native points
        // "HP/Atk/Def/SpA/SpD/Spe", 0–32 per stat), natures, teammates.
        func section(_ id: String, endIds: [String]) -> Substring {
            guard let start = html.range(of: "id=\"\(id)\"") else { return "" }
            var end = html.endIndex
            for endId in endIds {
                if let r = html.range(of: "id=\"\(endId)\"", range: start.upperBound..<html.endIndex),
                   r.lowerBound < end {
                    end = r.lowerBound
                }
            }
            return html[start.lowerBound..<end]
        }
        var spreads: [String: Double] = [:]
        let spreadSection = String(section("dex_spreads_wrapper", endIds: ["dex_natures_wrapper"]))
        if let entryRegex = try? NSRegularExpression(
            pattern: #"<div class="pokedex-move-entry-new">\s*<div class="pokedex-inline-text-offset">\s*</div>\s*((?:<div class="pokedex-inline-text">\d+/?</div>\s*)+)<div class="pokedex-inline-right">(\d+(?:\.\d+)?)%"#) {
            entryRegex.enumerateMatches(in: spreadSection,
                                        range: NSRange(spreadSection.startIndex..., in: spreadSection)) { m, _, _ in
                guard let m, spreads.count < 4,
                      let cellsRange = Range(m.range(at: 1), in: spreadSection),
                      let pctRange = Range(m.range(at: 2), in: spreadSection),
                      let pct = Double(spreadSection[pctRange]) else { return }
                let cells = String(spreadSection[cellsRange])
                var points: [String] = []
                if let digitRegex = try? NSRegularExpression(pattern: #">(\d+)/?<"#) {
                    digitRegex.enumerateMatches(in: cells,
                                                range: NSRange(cells.startIndex..., in: cells)) { d, _, _ in
                        guard let d, let r = Range(d.range(at: 1), in: cells) else { return }
                        points.append(String(cells[r]))
                    }
                }
                if points.count == 6 { spreads[points.joined(separator: "/")] = pct }
            }
        }
        var natures: [String: Double] = [:]
        let natureSection = String(section("dex_natures_wrapper", endIds: ["teammate_wrapper", "dex_team_wrapper"]))
        if let natureRegex = try? NSRegularExpression(
            pattern: #"<div class="pokedex-inline-text-offset">([A-Za-z]+)</div>\s*<div class="pokedex-inline-right">(\d+(?:\.\d+)?)%"#) {
            natureRegex.enumerateMatches(in: natureSection,
                                         range: NSRange(natureSection.startIndex..., in: natureSection)) { m, _, _ in
                guard let m, natures.count < 4,
                      let nameRange = Range(m.range(at: 1), in: natureSection),
                      let pctRange = Range(m.range(at: 2), in: natureSection),
                      let pct = Double(natureSection[pctRange]) else { return }
                natures[String(natureSection[nameRange])] = pct
            }
        }
        var teammates: [String] = []
        if let mateRegex = try? NSRegularExpression(
            pattern: #"<a class="teammate_entry[^>]*data-name="([^"]+)""#) {
            mateRegex.enumerateMatches(in: html, range: NSRange(html.startIndex..., in: html)) { m, _, _ in
                guard let m, teammates.count < 6,
                      let nameRange = Range(m.range(at: 1), in: html) else { return }
                let name = String(html[nameRange])
                if !teammates.contains(name) { teammates.append(name) }
            }
        }
        if !spreads.isEmpty { profile["spreads"] = spreads }
        if !natures.isEmpty { profile["natures"] = natures }
        if !teammates.isEmpty { profile["teammates"] = teammates }
        return profile
    }

    static func engineSlug(_ name: String) -> String {
        let lowered = name.lowercased()
        var out = ""
        var lastWasDash = false
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar), scalar.isASCII {
                out.append(Character(scalar))
                lastWasDash = false
            } else if !lastWasDash {
                out.append("-")
                lastWasDash = true
            }
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func discoverLinks(_ html: String, formatSlug: String,
                                      enqueue: (String) -> Void) {
        let patterns = [
            #"href="/pokedex/\#(formatSlug)/([^"]+)""#,
            #"championssprites/([a-z0-9-]+)\.png"#,
            #"data-candidates="([a-z0-9-]+)""#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            regex.enumerateMatches(in: html, range: NSRange(html.startIndex..., in: html)) { m, _, _ in
                guard let m, let r = Range(m.range(at: 1), in: html) else { return }
                let raw = String(html[r])
                // Canonicalize: strip query variants, decode, engine-slug.
                let path = raw.components(separatedBy: "?")[0]
                let decoded = path.removingPercentEncoding ?? path
                enqueue(engineSlug(decoded))
            }
        }
    }

    struct CrawlResult {
        let profiles: [String: Any]
        let pagesFetched: Int
    }

    /// Breadth-first closure over "appears in real teams", exactly as the
    /// CLI crawl: index page + seeds, then every species page's teammate/
    /// core links. 2 workers, 200ms spacing each, hard page cap
    /// (parameterized so smoke tests can run a bounded crawl).
    static func crawl(formatSlug: String,
                      cap: Int = MetaFetcher.cap,
                      progress: @escaping @Sendable (Int, Int, Int) -> Void)
        async throws -> CrawlResult {
        let index = "\(base)/pokedex/\(formatSlug)"

        // Single-threaded crawl STATE guarded by an actor: the queue, the
        // seen-set, and the output dict (workers only fetch + parse).
        actor State {
            var queued = Set<String>()
            var queue: [String] = []
            var profiles: [String: Any] = [:]
            var fetched = 0
            let cap: Int
            init(cap: Int) { self.cap = cap }
            func enqueue(_ slug: String) {
                guard !slug.isEmpty, !queued.contains(slug), queued.count < cap else { return }
                queued.insert(slug)
                queue.append(slug)
            }
            func next() -> String? { queue.isEmpty ? nil : queue.removeFirst() }
            func record(slug: String, profile: [String: Any]?) -> (Int, Int, Int) {
                fetched += 1
                if let profile { profiles[slug] = profile }
                return (fetched, queue.count, profiles.count)
            }
        }
        let state = State(cap: max(1, cap))

        let indexHTML = await get(index)
        guard !indexHTML.isEmpty else {
            throw FetchError(message: "Couldn't load \(index) — check the connection.")
        }
        var discovered: [String] = []
        discoverLinks(indexHTML, formatSlug: formatSlug) { discovered.append($0) }
        for slug in discovered { await state.enqueue(slug) }
        for seed in seeds { await state.enqueue(seed) }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrency {
                group.addTask {
                    while let slug = await state.next() {
                        let html = await get("\(index)/\(slug)")
                        var found: [String] = []
                        var profile: [String: Any]?
                        if !html.isEmpty {
                            profile = parseProfile(html)
                            discoverLinks(html, formatSlug: formatSlug) { found.append($0) }
                        }
                        for f in found { await state.enqueue(f) }
                        let (fetched, queued, profiles) = await state.record(slug: slug, profile: profile)
                        if fetched % 10 == 0 { progress(fetched, queued, profiles) }
                        try? await Task.sleep(nanoseconds: spacingNanos)
                    }
                }
            }
        }

        return CrawlResult(profiles: await state.profiles,
                           pagesFetched: await state.fetched)
    }
}

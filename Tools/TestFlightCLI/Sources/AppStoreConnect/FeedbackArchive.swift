import Foundation

/// Where fetched reports live: `~/.appstoreconnect/feedback/<bundle ID>/`, one folder per report with
/// its screenshots or crash log, a Markdown summary and an `item.json`, plus `state.json` recording
/// which reports have been dealt with. Outside the repository on purpose: reports carry tester emails
/// and personal screenshots, and Neodex is public.
public struct FeedbackArchive: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static func `default`(bundleID: String, directory: URL = Credentials.defaultDirectory) -> FeedbackArchive {
        FeedbackArchive(root: directory.appending(path: "feedback", directoryHint: .isDirectory)
            .appending(path: bundleID, directoryHint: .isDirectory))
    }

    // MARK: Handled reports

    /// TestFlight has no "resolved" state and deleting feedback is permanent, so handled reports are
    /// tracked here instead.
    public struct State: Codable, Sendable {
        public var handled: [String: Handled]

        public init(handled: [String: Handled] = [:]) {
            self.handled = handled
        }

        public struct Handled: Codable, Sendable {
            public var date: Date
            public var note: String?

            public init(date: Date, note: String?) {
                self.date = date
                self.note = note
            }
        }
    }

    var stateURL: URL { root.appending(path: "state.json", directoryHint: .notDirectory) }

    public func loadState() -> State {
        guard let data = try? Data(contentsOf: stateURL) else { return State() }
        return (try? Self.decoder.decode(State.self, from: data)) ?? State()
    }

    public func save(_ state: State) throws {
        try createRoot()
        try Self.encoder.encode(state).write(to: stateURL, options: .atomic)
    }

    // MARK: Report folders

    public func folder(for item: FeedbackItem) -> URL {
        root.appending(path: "\(Self.stamp(item.createdDate))-\(item.kind.rawValue)-\(Self.shortID(item.id))", directoryHint: .isDirectory)
    }

    public func prepareFolder(for item: FeedbackItem) throws -> URL {
        try createRoot()
        let folder = folder(for: item)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return folder
    }

    /// A file already saved as `<base>.<any extension>`, so screenshots and logs download once.
    public func existingFile(named base: String, in folder: URL) -> URL? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.sorted()
            .first { ($0 as NSString).deletingPathExtension == base }
            .map { folder.appending(path: $0, directoryHint: .notDirectory) }
    }

    public func writeDetails(for item: FeedbackItem, files: [String], in folder: URL) throws {
        let record = Record(id: item.id, kind: item.kind, createdDate: item.attributes.createdDate,
                            buildNumber: item.buildNumber, comment: item.attributes.comment, files: files)
        try Self.encoder.encode(record).write(to: folder.appending(path: "item.json"), options: .atomic)
        try Data(item.markdown(files: files).utf8).write(to: folder.appending(path: "feedback.md"), options: .atomic)
    }

    /// The IDs of every saved report.
    public func archivedIDs() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return names.compactMap { name in
            let url = root.appending(path: name, directoryHint: .isDirectory).appending(path: "item.json")
            guard let data = try? Data(contentsOf: url) else { return nil }
            return (try? Self.decoder.decode(Record.self, from: data))?.id
        }
    }

    /// A saved report's full ID from the start of it.
    public func resolve(_ prefix: String) throws -> String {
        let ids = Set(archivedIDs())
        if ids.contains(prefix) { return prefix }
        let matches = ids.filter { $0.hasPrefix(prefix) }
        guard matches.count <= 1 else {
            throw ASCError.unexpected("“\(prefix)” matches \(matches.count) reports. Give more of the ID.")
        }
        guard let match = matches.first else {
            throw ASCError.unexpected("No saved report starts with “\(prefix)”. Run Tools/testflight feedback (or crashes) first.")
        }
        return match
    }

    struct Record: Codable {
        var id: String
        var kind: FeedbackItem.Kind
        var createdDate: String?
        var buildNumber: String?
        var comment: String?
        var files: [String]
    }

    private func createRoot() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }

    /// "2026-10-27-2114", in local time, so folders sort by when the report was sent.
    static func stamp(_ date: Date?) -> String {
        guard let date else { return "undated" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }

    static func shortID(_ id: String) -> String {
        String(id.filter { $0.isLetter || $0.isNumber }.prefix(8))
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

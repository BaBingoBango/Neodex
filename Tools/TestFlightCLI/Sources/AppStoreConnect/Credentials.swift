import Foundation

/// The App Store Connect API key the tool signs requests with.
///
/// Only the key's identifiers and location are recorded. The private key itself stays in
/// `~/.appstoreconnect/private_keys`, the folder `altool` and `xcodebuild` also read, and never enters
/// the repository, which is public.
public struct Credentials: Sendable, Equatable {
    /// A team key's issuer ID. Nil for an individual key, which signs as `sub: user` instead.
    public var issuerID: String?
    public var keyID: String
    public var privateKeyURL: URL

    public init(issuerID: String?, keyID: String, privateKeyURL: URL) {
        self.issuerID = issuerID
        self.keyID = keyID
        self.privateKeyURL = privateKeyURL
    }

    public var kindDescription: String { issuerID == nil ? "individual key" : "team key" }

    /// The user's home folder, honouring `$HOME` the way other command-line tools do.
    public static var homeDirectory: URL {
        if let home = ProcessInfo.processInfo.environment["HOME"].nonEmpty {
            return URL(filePath: home, directoryHint: .isDirectory)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// `~/.appstoreconnect`.
    public static var defaultDirectory: URL {
        homeDirectory.appending(path: ".appstoreconnect", directoryHint: .isDirectory)
    }

    public static func configURL(in directory: URL) -> URL {
        directory.appending(path: "config.json", directoryHint: .notDirectory)
    }

    public static func defaultKeyURL(keyID: String, in directory: URL) -> URL {
        directory.appending(path: "private_keys", directoryHint: .isDirectory)
            .appending(path: "AuthKey_\(keyID).p8", directoryHint: .notDirectory)
    }

    /// The saved configuration. `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_PRIVATE_KEY_PATH` take precedence.
    public static func load(environment: [String: String] = ProcessInfo.processInfo.environment,
                            directory: URL = defaultDirectory) throws -> Credentials {
        let url = configURL(in: directory)
        var file = ConfigFile()
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                file = try JSONDecoder().decode(ConfigFile.self, from: Data(contentsOf: url))
            } catch {
                throw ASCError.configUnreadable(url)
            }
        }
        guard let keyID = environment["ASC_KEY_ID"].nonEmpty ?? file.keyID.nonEmpty else {
            throw ASCError.notConfigured
        }
        let issuerID = environment["ASC_ISSUER_ID"].nonEmpty ?? file.issuerID.nonEmpty
        let path = environment["ASC_PRIVATE_KEY_PATH"].nonEmpty ?? file.privateKeyPath.nonEmpty
        let keyURL = path.map { URL(filePath: ($0 as NSString).expandingTildeInPath) }
            ?? defaultKeyURL(keyID: keyID, in: directory)
        return Credentials(issuerID: issuerID, keyID: keyID, privateKeyURL: keyURL)
    }

    /// Writes the configuration, readable only by the user. The key's path is recorded only when it
    /// isn't the conventional one.
    public func save(in directory: URL = Self.defaultDirectory) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let conventional = Self.defaultKeyURL(keyID: keyID, in: directory).standardizedFileURL
        let file = ConfigFile(issuerID: issuerID, keyID: keyID,
                              privateKeyPath: privateKeyURL.standardizedFileURL == conventional ? nil : privateKeyURL.path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = Self.configURL(in: directory)
        try encoder.encode(file).write(to: url, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    struct ConfigFile: Codable {
        var issuerID: String?
        var keyID: String?
        var privateKeyPath: String?
    }
}

extension Optional where Wrapped == String {
    /// The trimmed value, or nil when it is missing or blank.
    var nonEmpty: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

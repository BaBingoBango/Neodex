import AppStoreConnect
import Foundation

/// `Tools/testflight`: TestFlight feedback, crash reports and build status for Neodex.
@main
struct TestFlight {
    static let defaultBundleID = "Ethan.Neodex"

    static let usage = """
    Usage: Tools/testflight <command> [options]

      setup --issuer-id <ID> --key-id <ID>   Save an App Store Connect API key's IDs and test it.
                                             The key file is moved from Downloads into
                                             ~/.appstoreconnect/private_keys if it is there.
            [--key-path <file>] [--individual]
      check                                  Test the connection and count TestFlight reports.
      feedback [--all] [--limit N] [--build N]
                                             Screenshot reports not yet marked handled, newest first,
                                             saved with their screenshots.
      crashes [--all] [--limit N] [--build N]
                                             Crash reports, saved with their crash logs.
      handled <ID>... [--note "…"]           Mark reports handled (the start of an ID is enough).
      reopen <ID>...                         Undo handled.
      builds [--limit N]                     Recent uploads and whether they finished processing.

    Every command takes --bundle-id (default \(defaultBundleID)). Reports are saved in
    ~/.appstoreconnect/feedback/<bundle ID>/, outside the repository.
    """

    static func main() async {
        // Line-buffer stdout so progress and errors stay in order when the output is piped.
        setvbuf(stdout, nil, _IOLBF, 0)
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    static func run(_ raw: [String]) async throws {
        let arguments = try Arguments(raw)
        switch arguments.command {
        case "setup"?: try await setup(arguments)
        case "check"?: try await check(arguments)
        case "feedback"?: try await list(.screenshot, arguments)
        case "crashes"?: try await list(.crash, arguments)
        case "handled"?: try mark(arguments, handled: true)
        case "reopen"?: try mark(arguments, handled: false)
        case "builds"?: try await builds(arguments)
        case nil, "help"?: print(usage)
        case let other?: throw ASCError.unexpected("Unknown command “\(other)”.\n\n" + usage)
        }
    }

    // MARK: setup and check

    static func setup(_ arguments: Arguments) async throws {
        guard let keyID = trimmed(arguments.options["key-id"]) else {
            throw ASCError.unexpected("setup needs --key-id, the Key ID shown in App Store Connect's keys table.")
        }
        let individual = arguments.flags.contains("individual")
        let issuerID = trimmed(arguments.options["issuer-id"])
        guard individual || issuerID != nil else {
            throw ASCError.unexpected("setup needs --issuer-id, shown above the keys table (or --individual for an individual key).")
        }
        let manager = FileManager.default
        let directory = Credentials.defaultDirectory
        var keyURL = Credentials.defaultKeyURL(keyID: keyID, in: directory)
        if let path = trimmed(arguments.options["key-path"]) {
            keyURL = URL(filePath: (path as NSString).expandingTildeInPath)
        } else if !manager.fileExists(atPath: keyURL.path) {
            let downloaded = Credentials.homeDirectory.appending(path: "Downloads/AuthKey_\(keyID).p8")
            if manager.fileExists(atPath: downloaded.path) {
                try manager.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
                try manager.moveItem(at: downloaded, to: keyURL)
                print("Moved AuthKey_\(keyID).p8 from Downloads to \(abbreviated(keyURL)).")
            }
        }
        guard manager.fileExists(atPath: keyURL.path) else { throw ASCError.keyMissing(keyURL) }
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        let credentials = Credentials(issuerID: individual ? nil : issuerID, keyID: keyID, privateKeyURL: keyURL)
        try credentials.save(in: directory)
        print("Saved the key's IDs to \(abbreviated(Credentials.configURL(in: directory))).")
        try await check(arguments, credentials: credentials)
    }

    static func check(_ arguments: Arguments, credentials given: Credentials? = nil) async throws {
        let credentials = try given ?? Credentials.load()
        let client = Client(credentials: credentials)
        let app = try await client.app(bundleID: arguments.bundleID)
        print("Connected with \(credentials.kindDescription) \(credentials.keyID).")
        print("\(app.name) (\(app.bundleID)) is app \(app.id).")
        let screenshots = try await client.feedbackTotal(.screenshot, appID: app.id)
        let crashes = try await client.feedbackTotal(.crash, appID: app.id)
        print("TestFlight holds \(count(screenshots, FeedbackItem.Kind.screenshot.noun)) and \(count(crashes, FeedbackItem.Kind.crash.noun)).")
    }

    // MARK: Reports

    static func list(_ kind: FeedbackItem.Kind, _ arguments: Arguments) async throws {
        let showAll = arguments.flags.contains("all")
        let limit = try arguments.integer("limit") ?? (showAll ? 200 : 50)
        let client = Client(credentials: try Credentials.load())
        let app = try await client.app(bundleID: arguments.bundleID)
        let archive = FeedbackArchive.default(bundleID: arguments.bundleID)
        let state = archive.loadState()
        let result = try await client.feedback(kind, appID: app.id, limit: limit)
        var items = result.items
        if let build = trimmed(arguments.options["build"]) { items = items.filter { $0.buildNumber == build } }
        let shown = showAll ? items : items.filter { state.handled[$0.id] == nil }

        let held = result.total.map { " TestFlight holds \(count($0, kind.noun))." } ?? ""
        guard !shown.isEmpty else {
            print("No \(showAll ? "" : "new ")\(kind.noun)s for \(app.name).\(held)")
            return
        }
        print("# \(count(shown.count, (showAll ? "" : "new ") + kind.noun)) for \(app.name)\(held.isEmpty ? "" : " (\(held.trimmingCharacters(in: .whitespaces)))")\n")

        for (index, item) in shown.enumerated() {
            let folder = try archive.prepareFolder(for: item)
            var files: [URL] = []
            var notes: [String] = []
            switch kind {
            case .screenshot:
                for (number, image) in (item.attributes.screenshots ?? []).enumerated() {
                    let base = "screenshot-\(number + 1)"
                    if let saved = archive.existingFile(named: base, in: folder) {
                        files.append(saved)
                        continue
                    }
                    guard let url = image.url else { continue }
                    do {
                        let download = try await client.download(url)
                        let file = folder.appending(path: "\(base).\(download.fileExtension)")
                        try download.data.write(to: file, options: .atomic)
                        files.append(file)
                    } catch {
                        notes.append("Screenshot \(number + 1) didn't download: \(error.localizedDescription)")
                    }
                }
            case .crash:
                if let saved = archive.existingFile(named: "crash", in: folder) {
                    files.append(saved)
                } else {
                    do {
                        if let log = try await client.crashLog(submissionID: item.id) {
                            // Crash logs arrive either as an .ips JSON report or as plain text.
                            let isJSON = log.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{")
                            let file = folder.appending(path: "crash.\(isJSON ? "ips" : "txt")")
                            try Data(log.utf8).write(to: file, options: .atomic)
                            files.append(file)
                        } else {
                            notes.append("This report came without a crash log.")
                        }
                    } catch {
                        notes.append("The crash log didn't download: \(error.localizedDescription)")
                    }
                }
            }
            try archive.writeDetails(for: item, files: files.map(\.lastPathComponent), in: folder)
            print(entry(index + 1, item, files: files, folder: folder, notes: notes, handled: state.handled[item.id]))
        }
        print("When one is dealt with: Tools/testflight handled <ID> --note \"what fixed it\"")
    }

    static func entry(_ number: Int, _ item: FeedbackItem, files: [URL], folder: URL, notes: [String],
                      handled: FeedbackArchive.State.Handled?) -> String {
        var heading = "## \(number). " + (item.createdDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Undated")
        if let build = item.buildNumber { heading += " · build \(build)" }
        if !item.deviceSummary.isEmpty { heading += " · \(item.deviceSummary)" }
        if let handled { heading += " · handled" + (handled.note.map { " (\($0))" } ?? "") }
        var lines = [heading]
        if let comment = item.comment {
            lines += comment.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" }
        } else {
            lines.append("> (no comment)")
        }
        for file in files {
            lines.append((file.deletingPathExtension().lastPathComponent == "crash" ? "Crash log: " : "Screenshot: ") + file.path)
        }
        lines += notes
        lines.append("Details: " + folder.appending(path: "feedback.md").path)
        lines.append("ID: \(item.id)")
        return lines.joined(separator: "\n") + "\n"
    }

    static func mark(_ arguments: Arguments, handled: Bool) throws {
        guard !arguments.positional.isEmpty else {
            throw ASCError.unexpected("Name at least one report ID; the start of one is enough.")
        }
        let archive = FeedbackArchive.default(bundleID: arguments.bundleID)
        var state = archive.loadState()
        for prefix in arguments.positional {
            let id = try archive.resolve(prefix)
            if handled {
                state.handled[id] = FeedbackArchive.State.Handled(date: .now, note: trimmed(arguments.options["note"]))
                print("Marked \(id) handled.")
            } else {
                state.handled[id] = nil
                print("Reopened \(id).")
            }
        }
        try archive.save(state)
    }

    // MARK: Builds

    static func builds(_ arguments: Arguments) async throws {
        let client = Client(credentials: try Credentials.load())
        let app = try await client.app(bundleID: arguments.bundleID)
        let builds = try await client.builds(appID: app.id, limit: try arguments.integer("limit") ?? 10)
        print("# Recent builds of \(app.name)\n")
        for build in builds {
            var line = "- \(build.marketingVersion ?? "?") (\(build.number ?? "?"))"
            if let platform = Platform.name(build.platform) { line += " · \(platform)" }
            line += " · " + state(build.processingState)
            if let uploaded = build.uploaded { line += " · uploaded \(uploaded.formatted(date: .abbreviated, time: .shortened))" }
            if build.expired {
                line += " · expired"
            } else if let expires = build.expires {
                line += " · expires \(expires.formatted(date: .abbreviated, time: .omitted))"
            }
            print(line)
        }
    }

    static func state(_ raw: String?) -> String {
        switch raw {
        case "VALID"?: return "ready to test"
        case "PROCESSING"?: return "processing"
        case "FAILED"?: return "processing failed"
        case "INVALID"?: return "invalid"
        case let other?: return other.lowercased()
        case nil: return "state unknown"
        }
    }

    // MARK: Helpers

    static func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }

    static func trimmed(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    static func abbreviated(_ url: URL) -> String {
        let home = Credentials.homeDirectory.path
        return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    }
}

/// `<command> [positional…] [--option value] [--flag]`, with unknown options rejected so typos surface.
struct Arguments {
    var command: String?
    var positional: [String] = []
    var options: [String: String] = [:]
    var flags: Set<String> = []

    static let valueOptions: Set<String> = ["issuer-id", "key-id", "key-path", "limit", "build", "note", "bundle-id"]
    static let flagOptions: Set<String> = ["all", "individual", "help"]

    init(_ raw: [String]) throws {
        var remaining = raw[...]
        while let argument = remaining.popFirst() {
            if argument.hasPrefix("--") {
                var name = String(argument.dropFirst(2))
                var value: String?
                if let equals = name.firstIndex(of: "=") {
                    value = String(name[name.index(after: equals)...])
                    name = String(name[..<equals])
                }
                if Self.valueOptions.contains(name) {
                    guard let given = value ?? remaining.popFirst() else {
                        throw ASCError.unexpected("--\(name) needs a value.")
                    }
                    options[name] = given
                } else if Self.flagOptions.contains(name), value == nil {
                    flags.insert(name)
                } else {
                    throw ASCError.unexpected("Unknown option --\(name). Run Tools/testflight help.")
                }
            } else if argument == "-h" {
                flags.insert("help")
            } else if command == nil {
                command = argument
            } else {
                positional.append(argument)
            }
        }
        if flags.contains("help") { command = "help" }
    }

    var bundleID: String { options["bundle-id"] ?? TestFlight.defaultBundleID }

    func integer(_ name: String) throws -> Int? {
        guard let text = options[name] else { return nil }
        guard let value = Int(text), value > 0 else { throw ASCError.unexpected("--\(name) needs a positive number.") }
        return value
    }
}

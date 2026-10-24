//
//  ScoutReport.swift  (diagnostic CLI)
//
//  End-to-end Phase 1: feeds the visual pipeline's opponent reads into the
//  TypeScript engine (Tools/ScopeLensEngine/dist/engine.js, run in JavaScriptCore) and prints
//  the team-preview scout report.
//
//  Build & run (from repo root; m9 — our team comes from the committed
//  default paste, the same file the app bundles):
//    swiftc -O Tools/ScopeLensDiagnostics/ScoutReport.swift "Packages/ScopeLens/Sources/ScopeLens/TeamStore.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/ScoutEngine.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleState.swift" \
//      -o /tmp/scoutreport && /tmp/scoutreport
//
//  Usage:
//    scoutreport [fixtureStem] [row=Species ...]
//  Example:
//    scoutreport Team_Preview_Initial 4=Archaludon
//  Overrides simulate the user's confirm-tap when the sprite matcher's top-1
//  is wrong (the report shows top-3; one tap fixes a row).
//
//  NOTE for sample regeneration: the committed Team_Preview_Initial_scout.md
//  was generated with FOUR taps — `1=Farigiraf 2=Charizard 3=Pelipper
//  4=Archaludon` (the recorded exact invocation; see Tools/ScopeLensDiagnostics/README.md).
//
import Foundation
import JavaScriptCore

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

@main
struct ScoutReportCLI {
    static func main() {
        let repoRoot = FileManager.default.currentDirectoryPath
        let fm = FileManager.default
        func err(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

        let args = CommandLine.arguments.dropFirst()
        let fixture = args.first(where: { !$0.contains("=") }) ?? "Team_Preview_Initial"
        var overrides: [Int: String] = [:]
        for a in args where a.contains("=") {
            let parts = a.split(separator: "=", maxSplits: 1)
            if parts.count == 2, let row = Int(parts[0]) { overrides[row] = String(parts[1]) }
        }

        // ---- opponent team from the visual pipeline ------------------------
        guard let sData = fm.contents(atPath: "\(scopeLensFixturesRoot)/preview/species.json"),
              let sJSON = try? JSONSerialization.jsonObject(with: sData) as? [String: [[String: Any]]],
              let rows = sJSON[fixture] else {
            err("no species.json entry for fixture \(fixture)"); exit(1)
        }
        var theirs: [[String: Any]] = []
        var pipelineNotes: [String] = []
        for r in rows.sorted(by: { ($0["row"] as! Int) < ($1["row"] as! Int) }) {
            let n = r["row"] as! Int
            let top = (r["top"] as? [[String: Any]]) ?? []
            let names = top.compactMap { $0["name"] as? String }
            let pick = overrides[n] ?? names.first ?? "?"
            theirs.append(["species": pick])
            let marker = overrides[n] != nil ? " (confirmed by tap)" : ""
            pipelineNotes.append("row \(n): \(pick)\(marker)  [matcher: \(names.joined(separator: " | "))]")
        }

        // ---- our team: the committed default paste (m9) ---------------------
        guard let (team, _, issues) = try? Team.fromRepoDefault(root: repoRoot),
              !issues.contains(where: { $0.severity == .error }) else {
            err("cannot load \(Team.defaultPasteRepoPath) — run from the repo root"); exit(1)
        }
        let mine: [[String: Any]] = team.members.map { $0.monSpec.asDictionary }

        // ---- run the engine in JavaScriptCore --------------------------------
        guard let engineSrc = try? String(contentsOfFile: "\(repoRoot)/Tools/ScopeLensEngine/dist/engine.js", encoding: .utf8),
              let ctx = JSContext() else { err("cannot load engine"); exit(1) }
        ctx.exceptionHandler = { _, ex in err("JS exception: \(ex?.toString() ?? "?")") }
        ctx.evaluateScript(engineSrc)
        guard let engine = ctx.objectForKeyedSubscript("ScopeEngine"),
              let fn = engine.objectForKeyedSubscript("scoutReport"), fn.isObject else {
            err("ScopeEngine.scoutReport not found"); exit(1)
        }
        let result = fn.call(withArguments: [mine, theirs])
        guard let dict = result?.toDictionary(),
              let markdown = dict["markdown"] as? String else { err("engine returned nothing"); exit(1) }

        // ---- output ----------------------------------------------------------
        var out = markdown
        out += "\n\n## Pipeline reads (\(fixture))\n"
        for n in pipelineNotes { out += "- \(n)\n" }
        print(out)
        try? out.write(toFile: "\(scopeLensFixturesRoot)/preview/\(fixture)_scout.md",
                       atomically: true, encoding: .utf8)
        err("\nwrote Fixtures/preview/\(fixture)_scout.md")
    }
}

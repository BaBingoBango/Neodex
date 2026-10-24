import Testing
@testable import ScopeLens

/// The package carries the engine, vocabulary, icon templates and species index as resources;
/// these prove they ship and load from `Bundle.module` the way the standalone app loaded them.
struct BundledResourcesTests {
    @Test func engineLoadsAndReports() throws {
        let engine = try ScoutEngine.bundled()
        let report = try engine.report(mine: [MonSpec(species: "Incineroar")], theirs: ["Flutter Mane"])
        #expect(!report.opponents.isEmpty)
        #expect(report.opponents.first?.species.lowercased().contains("flutter") == true)
    }

    @Test func vocabularySnapsMoves() throws {
        let vocabulary = try BattleVocabulary.bundled()
        #expect(vocabulary.snapMove("Protct")?.value == "Protect")
    }

    @Test func speciesIndexIsBundled() {
        let names = PreviewPipeline.bundledSpeciesNames()
        #expect(names.count > 100)
        #expect(names.contains("Incineroar"))
    }

    @Test func advisorToolSchemasAreBundled() throws {
        #expect(try AdvisorToolCatalog.bundled().count >= 6)
    }
}

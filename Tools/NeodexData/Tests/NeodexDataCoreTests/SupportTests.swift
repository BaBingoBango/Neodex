import CoreGraphics
import Foundation
import Testing
@testable import NeodexDataCore

@Suite("CSV reader")
struct CSVTests {
    @Test("Quoted fields, escaped quotes, embedded newlines and CRLF")
    func parsesTrickyFields() {
        let text = "id,name,text\n1,Bulbasaur,\"A strange seed, with a \"\"bulb\"\".\nIt grows.\"\n2,Ivysaur,plain\r\n"
        let table = CSVTable(data: Data(text.utf8))
        #expect(table.header == ["id", "name", "text"])
        #expect(table.rows.count == 2)
        let rows = table.dictionaries
        #expect(rows[0]["name"] == "Bulbasaur")
        #expect(rows[0]["text"] == "A strange seed, with a \"bulb\".\nIt grows.")
        #expect(rows[1]["name"] == "Ivysaur")
        #expect(rows[1]["text"] == "plain")
        #expect(rows[1].int("id") == 2)
        #expect(rows[1]["missing"] == "")
        #expect(rows[1].string("missing") == nil)
    }

    @Test("Typed accessors")
    func accessors() {
        let table = CSVTable(data: Data("a,b,c,d\n1,2.5,1,\n".utf8))
        let row = table.dictionaries[0]
        #expect(row.int("a") == 1)
        #expect(row.double("b") == 2.5)
        #expect(row.bool("c"))
        #expect(!row.bool("d"))
        #expect(row.string("d") == nil)
    }
}

@Suite("Loose JSON values")
struct JSONValueTests {
    @Test("Heterogeneous documents decode and expose typed accessors")
    func decodes() throws {
        let json = #"{"a":1,"b":"x","c":true,"d":null,"e":[1,"y"],"f":{"g":2.5},"h":["p","q"]}"#
        let value = try JSONValue.decode(Data(json.utf8))
        #expect(value["a"]?.int == 1)
        #expect(value["b"]?.string == "x")
        #expect(value["c"]?.isTrue == true)
        #expect(value["d"]?.isNull == true)
        #expect(value["e"]?.array?.count == 2)
        #expect(value["e"]?.stringArray == ["y"])
        #expect(value["f"]?["g"]?.double == 2.5)
        #expect(value["b"]?.stringOrStrings == ["x"])
        #expect(value["h"]?.stringOrStrings == ["p", "q"])
        #expect(value["missing"] == nil)
    }
}

@Suite("JavaScript and TypeScript evaluation")
struct JSEvaluatorTests {
    @Test("Showdown client modules export plain objects")
    func clientModule() throws {
        let source = #"exports.BattlePokedex = {bulbasaur:{num:1,name:"Bulbasaur",types:["Grass","Poison"],abilities:{"0":"Overgrow",H:"Chlorophyll"}}};"#
        let json = try JSEvaluator.clientModuleJSON(source, exportName: "BattlePokedex")
        let value = try JSONValue.decode(json)
        #expect(value["bulbasaur"]?["num"]?.int == 1)
        #expect(value["bulbasaur"]?["abilities"]?["H"]?.string == "Chlorophyll")
    }

    @Test("A missing export is reported")
    func missingExport() {
        #expect(throws: JSEvaluator.EvaluationError.self) {
            try JSEvaluator.clientModuleJSON("exports.Other = {};", exportName: "BattlePokedex")
        }
    }

    @Test("Showdown server TypeScript modules evaluate without a TypeScript compiler")
    func typeScriptModule() throws {
        let source = """
        export const Natures: import('../sim/dex-data').NatureDataTable = {
        \tadamant: {
        \t\tname: "Adamant",
        \t\tplus: 'atk',
        \t\tminus: 'spa',
        \t},
        \thardy: {
        \t\tname: "Hardy",
        \t},
        };

        export default Natures;
        """
        let value = try JSONValue.decode(try JSEvaluator.typeScriptModuleJSON(source))
        #expect(value.object?.count == 2)
        #expect(value["adamant"]?["plus"]?.string == "atk")
        #expect(value["hardy"]?["plus"] == nil)
    }

    @Test("A file without an exported object literal is rejected")
    func unsupportedModule() {
        #expect(throws: JSEvaluator.EvaluationError.self) {
            try JSEvaluator.typeScriptModuleJSON("import x from 'y';\nconsole.log(x);")
        }
    }
}

@Suite("Name mapping and classification")
struct NameMappingTests {
    @Test("Showdown names become PokeAPI identifiers")
    func identifiers() {
        #expect(DatasetBuilder.pokeapiIdentifier(for: "Mr. Mime") == "mr-mime")
        #expect(DatasetBuilder.pokeapiIdentifier(for: "Flabébé") == "flabebe")
        #expect(DatasetBuilder.pokeapiIdentifier(for: "Farfetch’d") == "farfetchd")
        #expect(DatasetBuilder.pokeapiIdentifier(for: "Type: Null") == "type-null")
        #expect(DatasetBuilder.pokeapiIdentifier(for: "Ogerpon-Wellspring") == "ogerpon-wellspring")
        #expect(DatasetBuilder.pokeapiIdentifier(for: "Zygarde-10%") == "zygarde-10")
    }

    @Test("Every alias is a well-formed identifier")
    func aliases() {
        let pattern = /^[a-z0-9-]+$/
        for (key, value) in DatasetBuilder.formAliases {
            #expect(key.wholeMatch(of: pattern) != nil, "key \(key)")
            #expect(value.wholeMatch(of: pattern) != nil, "value \(value)")
        }
        #expect(DatasetBuilder.formAliases["ogerpon-wellspring"] == "ogerpon-wellspring-mask")
    }

    @Test("Showdown IDs and sprite stems")
    func showdownIDs() throws {
        #expect(ShowdownData.toID("Charizard-Mega-X") == "charizardmegax")
        #expect(ShowdownData.toID("Flabébé") == "flabebe")
        let mega = try JSONValue.decode(Data(#"{"name":"Charizard-Mega-X","baseSpecies":"Charizard","forme":"Mega-X"}"#.utf8))
        #expect(ShowdownData.spriteID(for: mega) == "charizard-megax")
        let plain = try JSONValue.decode(Data(#"{"name":"Pikachu"}"#.utf8))
        #expect(ShowdownData.spriteID(for: plain) == "pikachu")
    }

    @Test("Form kinds and generations")
    func classification() {
        #expect(DatasetBuilder.formKind(forForme: "Mega-X") == .mega)
        #expect(DatasetBuilder.formKind(forForme: "Gmax") == .gigantamax)
        #expect(DatasetBuilder.formKind(forForme: "Alola") == .alolan)
        #expect(DatasetBuilder.formKind(forForme: "Galar-Zen") == .galarian)
        #expect(DatasetBuilder.formKind(forForme: "Hisui") == .hisuian)
        #expect(DatasetBuilder.formKind(forForme: "Paldea-Combat") == .paldean)
        #expect(DatasetBuilder.formKind(forForme: "Totem") == .totem)
        #expect(DatasetBuilder.formKind(forForme: "Wellspring-Tera") == .terastal)
        #expect(DatasetBuilder.formKind(forForme: "Wellspring") == .other)

        #expect(DatasetBuilder.generation(forDexNumber: 151) == 1)
        #expect(DatasetBuilder.generation(forDexNumber: 152) == 2)
        #expect(DatasetBuilder.generation(forDexNumber: 905) == 8)
        #expect(DatasetBuilder.generation(forDexNumber: 1025) == 9)
        #expect(DatasetBuilder.generation(forForme: "Mega", formKind: .mega, speciesNum: 3, species: nil) == 6)
        #expect(DatasetBuilder.generation(forForme: "Alola", formKind: .alolan, speciesNum: 26, species: nil) == 7)
        #expect(DatasetBuilder.moveGeneration(num: 826) == 8)
        #expect(DatasetBuilder.moveGeneration(num: 827) == 9)
        #expect(DatasetBuilder.abilityGeneration(num: 267) == 8)
        #expect(DatasetBuilder.abilityGeneration(num: 268) == 9)
    }

    @Test("Game text is normalised")
    func flavorText() {
        #expect(PokeAPIData.cleanFlavor("A strange seed was\nplanted\u{0C}on its back.") == "A strange seed was planted on its back.")
        #expect(PokeAPIData.cleanFlavor("A POKéMON with a soft\u{00AD}hyphen.") == "A Pokémon with a softhyphen.")
        #expect(PokeAPIData.growthRateName("medium slow") == "Medium Slow")
        #expect(PokeAPIData.growthRateName("medium") == "Medium Fast")
        #expect(PokeAPIData.growthRateName("slow then very fast") == "Erratic")
        #expect(PokeAPIData.growthRateName("fast then very slow") == "Fluctuating")
    }
}

@Suite("Image conversion")
struct ImageConverterTests {
    @Test("Artwork is resized and written as HEIC and PNG")
    func convertsImages() throws {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 500, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0.5, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 500, height: 300))
        let image = try #require(context.makeImage())

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("neodex-image-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let heic = directory.appendingPathComponent("art.heic")
        try ImageConverter.writeHEIC(image, maxDimension: 400, quality: 0.8, to: heic)
        let decodedHEIC = try #require(ImageConverter.image(from: Data(contentsOf: heic)))
        #expect(decodedHEIC.width == 400)
        #expect(decodedHEIC.height == 240)

        let png = directory.appendingPathComponent("sprite.png")
        try ImageConverter.writePNG(try #require(image.cropping(to: CGRect(x: 0, y: 0, width: 24, height: 24))), to: png)
        let decodedPNG = try #require(ImageConverter.image(from: Data(contentsOf: png)))
        #expect(decodedPNG.width == 24 && decodedPNG.height == 24)
    }
}

import FoundationModels
import NeodexKit
import Observation

/// One friendly sentence per Home pick, written on device by Apple Intelligence when it's available.
/// The model only rephrases facts the app hands it (types, genus, egg groups and what was viewed).
@Observable
@MainActor
final class PickExplainer {
    static let shared = PickExplainer()

    struct Blurb: Identifiable, Hashable {
        var pokemonID: String
        var text: String
        var id: String { pokemonID }
    }

    private(set) var blurbs: [Blurb] = []
    private(set) var isGenerating = false
    private var explainedKey = ""

    /// `true` when the on-device model can run here (eligible device, Apple Intelligence on, model ready).
    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Writes reasons for up to three picks. Cached until the picks or the recent history change.
    func explain(picks: [Pokemon], basedOn recent: [Pokemon]) async {
        let picks = Array(picks.prefix(3))
        let recent = Array(recent.prefix(5))
        guard isAvailable, !picks.isEmpty, !recent.isEmpty else {
            blurbs = []
            return
        }
        let key = picks.map(\.id).joined(separator: ",") + "|" + recent.map(\.id).joined(separator: ",")
        guard key != explainedKey, !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        let session = LanguageModelSession(instructions: """
            You write one warm, specific sentence per Pokémon explaining why a Pokédex app is suggesting it, \
            based on the Pokémon the user looked at recently. Use only the facts provided: types, genus and egg \
            groups. Never invent stats, moves, locations or lore. Keep every sentence under 20 words and do not \
            start with the Pokémon's name.
            """)
        let recentText = recent.map { "\($0.displayName) (\($0.types.map(\.name).joined(separator: "/")))" }.joined(separator: ", ")
        let pickText = picks.enumerated().map { index, pokemon in
            "\(index + 1). \(pokemon.displayName): \(pokemon.types.map(\.name).joined(separator: "/")) type, "
                + "the \(pokemon.genus ?? "mystery") Pokémon, egg groups \(pokemon.eggGroups.joined(separator: " and "))"
        }.joined(separator: "\n")
        do {
            let response = try await session.respond(
                to: "Recently viewed: \(recentText)\nWrite one sentence for each of these, in order:\n\(pickText)",
                generating: PickReasons.self
            )
            blurbs = zip(picks, response.content.reasons).map { Blurb(pokemonID: $0.id, text: $1) }
            explainedKey = key
        } catch {
            blurbs = []
        }
    }
}

@Generable(description: "Short reasons for recommending each listed Pokémon, in the same order.")
nonisolated struct PickReasons {
    @Guide(description: "Exactly one sentence per Pokémon, in the order they were listed.", .count(3))
    var reasons: [String]
}

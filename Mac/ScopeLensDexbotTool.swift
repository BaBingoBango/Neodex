import FoundationModels
import ScopeLens

/// Dexbot's window into Scope Lens on the Mac.
nonisolated enum ScopeLensDexbot {
    /// Appended to Dexbot's instructions on the Mac.
    static let instructions = """
         On this Mac, Scope Lens may be tracking a live Pokémon Champions battle. For any question about the battle, \
        the board, this turn, the opponent or the play, call liveBattle first and reason only from what it returns. \
        Champions is VGC doubles with Mega Evolution and without Terastallization. Keep battle advice to the play \
        and the one risk that matters.
        """
}

/// The live battle Scope Lens is watching, for Dexbot. It reads the same published state the Battle Log
/// shows, so the answer is grounded in what the screen said rather than invented.
nonisolated struct LiveBattleTool: Tool {
    let name = "liveBattle"
    let description = "The Pokémon Champions battle Scope Lens is tracking on this Mac right now: both sides' Pokémon with HP, status and boosts, what the opponent has revealed, usage-based likely sets, the speed order and damage lines, and the recent log. Use it for anything about the current battle, the board, this turn or what the play is."

    @Generable
    struct Arguments {
        @Guide(description: "Optional: what to focus on, e.g. 'the opponent's Incineroar' or 'speed order'.")
        var focus: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let summary = await MainActor.run { LiveTrackerModel.shared.liveBattleSummary() }
        guard let summary else {
            return "Scope Lens isn't tracking a battle right now. In Neodex, open Scope Lens in the sidebar, press Start with the mirrored game up, and queue into a battle."
        }
        if let focus = arguments.focus, !focus.isEmpty {
            return "Focus: \(focus)\n\n" + summary
        }
        return summary
    }
}

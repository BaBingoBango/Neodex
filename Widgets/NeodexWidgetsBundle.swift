import SwiftUI
import WidgetKit

@main
struct NeodexWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PokemonOfTheDayWidget()
        MysteryPokemonWidget()
        TeamWidget()
        LeaderboardWidget()
        RandomPokemonControl()
        DamageCalcControl()
    }
}

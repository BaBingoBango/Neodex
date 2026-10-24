import SwiftUI
import WidgetKit

/// The watch face complications and Smart Stack widgets.
@main
struct NeodexWatchWidgets: WidgetBundle {
    var body: some Widget {
        PokemonOfTheDayComplication()
        MysteryComplication()
        OpenNeodexComplication()
    }
}

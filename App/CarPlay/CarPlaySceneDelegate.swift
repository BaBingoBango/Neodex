#if canImport(CarPlay)
import CarPlay
import UIKit

/// CarPlay entry point. Declared in Info.plist for the CarPlay scene role; only ever instantiated in a
/// car (or the CarPlay Simulator) when the app has the voice-based-conversation entitlement.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private let dexbot = CarPlayDexbot()

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        dexbot.connect(interfaceController)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        dexbot.disconnect()
    }
}
#endif

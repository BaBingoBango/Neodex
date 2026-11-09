#if os(iOS)
import UIKit

/// Home Screen quick actions: touch and hold Neodex's icon for Search, Ask Dexbot, Scan a Pokémon and
/// Damage Calc. They are declared in Info.plist (`UIApplicationShortcutItems`), so they are there
/// before the first launch, and each one's type is the `neodex://` link it opens.
///
/// SwiftUI has no hook for them: UIKit hands a chosen action to the window scene's delegate, so the
/// app delegate gives SwiftUI's scenes one.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // The session's own configuration, so CarPlay's scene keeps the delegate Info.plist names.
        let configuration = connectingSceneSession.configuration
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = QuickActionSceneDelegate.self
        }
        return configuration
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    /// An action that launched the app arrives with the scene.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem { _ = open(item) }
    }

    /// An action chosen while the app was already running.
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem) async -> Bool {
        open(shortcutItem)
    }

    private func open(_ item: UIApplicationShortcutItem) -> Bool {
        guard let url = URL(string: item.type), url.scheme == SharedContainer.urlScheme else { return false }
        DeepLinkRouter.shared.open(url: url)
        return true
    }
}
#endif

import Foundation
import Observation

/// Screens requested from outside the app — Spotlight, Siri, widgets, controls and Home Screen quick
/// actions — presented once data is ready.
@Observable
@MainActor
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    /// Requests that need the database to resolve (a random or daily Pokémon); `MainTabView` turns them into routes.
    enum PickRequest: Hashable {
        case random, today, mystery
    }

    var pendingRoute: AppRoute?
    var pendingPick: PickRequest?
    /// A sidebar destination to switch to (Scope Lens's "Ask Dexbot" lands on the Dexbot tab).
    var pendingTab: AppTab?
    /// A question for the Dexbot tab to open as a new chat.
    var pendingDexbotQuestion: String?
    /// A new Dexbot chat to show over whatever is on screen, on iPhone and iPad.
    var pendingDexbotStart: DexbotView.Start?
    /// Set when Search should open with its field ready to type in.
    var wantsSearchFocus = false

    func open(_ route: AppRoute) {
        pendingRoute = route
    }

    /// Switches to Dexbot and asks `question` in a new chat.
    func askDexbot(_ question: String) {
        pendingTab = .dexbot
        pendingDexbotQuestion = question
    }

    /// Starts a new Dexbot chat, ready to type: in a sheet on iPhone and iPad, where Dexbot may not
    /// be in the tab bar, and in Dexbot's own section on the Mac.
    func startDexbotChat() {
        #if os(macOS)
        pendingTab = .dexbot
        #else
        pendingDexbotStart = .typing
        #endif
    }

    /// Handles `neodex://` links from widgets, controls and Home Screen quick actions.
    func open(url: URL) {
        guard url.scheme == SharedContainer.urlScheme else { return }
        let argument = url.pathComponents.dropFirst().first
        switch url.host() {
        case "search":
            pendingTab = .search
            wantsSearchFocus = true
        case "dexbot":
            startDexbotChat()
        case "pokemon":
            if let argument { pendingRoute = .pokemon(argument) }
        case "team":
            if let argument, let id = UUID(uuidString: argument) { pendingRoute = .team(id) }
        case "stats":
            pendingRoute = .usageStats(format: argument)
        case "calc":
            pendingRoute = .damageCalculator(attacker: nil, defender: nil)
        case "scan":
            pendingRoute = .scan
        case "random":
            pendingPick = .random
        case "today":
            pendingPick = .today
        case "mystery":
            pendingPick = .mystery
        default:
            break
        }
    }
}

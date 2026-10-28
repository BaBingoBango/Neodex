import Foundation
import Observation

/// Screens requested from outside the app — Spotlight, Siri, widgets and controls — presented once data is ready.
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

    func open(_ route: AppRoute) {
        pendingRoute = route
    }

    /// Switches to Dexbot and asks `question` in a new chat.
    func askDexbot(_ question: String) {
        pendingTab = .dexbot
        pendingDexbotQuestion = question
    }

    /// Handles `neodex://` links from widgets and controls.
    func open(url: URL) {
        guard url.scheme == SharedContainer.urlScheme else { return }
        let argument = url.pathComponents.dropFirst().first
        switch url.host() {
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

import Observation

/// Screens requested from outside the app — Spotlight, Siri and Shortcuts — presented once data is ready.
@Observable
@MainActor
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    var pendingRoute: AppRoute?

    func open(_ route: AppRoute) {
        pendingRoute = route
    }
}

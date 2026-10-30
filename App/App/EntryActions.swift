import NeodexKit
import SwiftUI

/// What a link to a Pokédex entry offers besides opening it. Its context menu has Open in New Window
/// wherever the app can show more than one window (iPad and the Mac) and, for a Pokémon, Favorites and
/// Face-Off. A Pokémon can also be dragged, as its `neodex://pokemon/<id>` link, and dropping another
/// Pokémon on it opens a Face-Off between the two.
struct EntryActions: ViewModifier {
    var route: AppRoute
    /// The Pokémon the link is about: the route's own, or the one a usage statistics link is about.
    var pokemonID: Pokemon.ID?

    @Environment(\.database) private var database
    @Environment(\.openWindow) private var openWindow
    @Environment(\.presentRoute) private var presentRoute
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @State private var favorites = FavoritePokemon.shared
    @State private var isDropTarget = false

    /// The symbol for Open in New Window: a Mac window on the Mac, side-by-side windows on iPad.
    static var newWindowImage: String {
        #if os(macOS)
        "macwindow.badge.plus"
        #else
        "square.split.2x1"
        #endif
    }

    func body(content: Content) -> some View {
        if let id = pokemonID {
            content
                .contextMenu {
                    openInNewWindow
                    let isFavorite = favorites.contains(id)
                    Button(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.slash" : "heart") {
                        favorites.toggle(id)
                    }
                    Button("Face-Off", systemImage: "bolt.circle") { show(.faceOff(id)) }
                }
                .draggable(PokemonDrag.url(for: id))
                .dropDestination(for: URL.self) { urls, _ in faceOff(urls, against: id) }
                .onDropSessionUpdated { session in
                    isDropTarget = session.phase == .entering || session.phase == .active
                }
                .overlay {
                    if isDropTarget {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.tint, lineWidth: 3)
                            .allowsHitTesting(false)
                    }
                }
        } else if supportsMultipleWindows {
            content.contextMenu { openInNewWindow }
        } else {
            content
        }
    }

    @ViewBuilder
    private var openInNewWindow: some View {
        if supportsMultipleWindows {
            Button("Open in New Window", systemImage: Self.newWindowImage) { openWindow(value: route) }
        }
    }

    /// Opens a Face-Off between the Pokémon dropped here and this one.
    private func faceOff(_ urls: [URL], against target: Pokemon.ID) {
        guard let dropped = urls.lazy.compactMap(PokemonDrag.pokemonID(in:)).first,
              dropped != target, database.pokemon(id: dropped) != nil else { return }
        show(.faceOff(dropped, versus: target))
    }

    /// The Mac shows it in a window of its own, like every entry it opens from elsewhere; iPhone and iPad
    /// show it over the window or sheet the link is in.
    private func show(_ route: AppRoute) {
        #if os(macOS)
        openWindow(value: route)
        #else
        presentRoute(route)
        #endif
    }
}

/// Shows an entry over the window or sheet it was asked for in, on iPhone and iPad. Each window and sheet
/// that holds entry links installs one (`routePresenter()`); without one, the app-wide router shows it over
/// the main window.
nonisolated struct PresentRouteAction: Sendable {
    let action: @MainActor (AppRoute) -> Void

    @MainActor func callAsFunction(_ route: AppRoute) { action(route) }
}

extension EnvironmentValues {
    @Entry var presentRoute = PresentRouteAction { DeepLinkRouter.shared.open($0) }
}

/// Presents the entries asked for inside this window or sheet, in a sheet of their own (see `PresentRouteAction`).
private struct RoutePresenter: ViewModifier {
    @State private var shown: AppRoute?

    func body(content: Content) -> some View {
        content
            .environment(\.presentRoute, PresentRouteAction { shown = $0 })
            .sheet(item: $shown) { RouteSheet(route: $0) }
    }
}

/// An entry shown over the window, with Done to put it away.
struct RouteSheet: View {
    @Environment(\.dismiss) private var dismiss
    var route: AppRoute

    var body: some View {
        NavigationStack {
            AppRouteView(route: route)
                .appDestinations()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .routePresenter()
    }
}

/// A Pokémon in a drag travels as its `neodex://pokemon/<id>` link, so it also drops into other apps as a link.
nonisolated enum PokemonDrag {
    static func url(for id: Pokemon.ID) -> URL { SharedContainer.deepLink("pokemon/\(id)") }

    static func pokemonID(in url: URL) -> Pokemon.ID? {
        guard url.scheme == SharedContainer.urlScheme, url.host() == "pokemon" else { return nil }
        return url.pathComponents.dropFirst().first
    }
}

extension View {
    /// Presents entries asked for by links inside this view over it, on iPhone and iPad. The Mac opens them
    /// in windows of their own instead.
    @ViewBuilder
    func routePresenter() -> some View {
        #if os(macOS)
        self
        #else
        modifier(RoutePresenter())
        #endif
    }

    /// Adds an entry link's context menu and, for a Pokémon, dragging and dropping (see `EntryActions`).
    /// A link that isn't to a Pokémon's page, like its usage statistics, passes the Pokémon it's about.
    func entryActions(_ route: AppRoute, pokemon: Pokemon.ID? = nil) -> some View {
        var pokemonID = pokemon
        if case .pokemon(let id) = route { pokemonID = id }
        return modifier(EntryActions(route: route, pokemonID: pokemonID))
    }
}

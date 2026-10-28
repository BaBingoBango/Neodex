import NeodexKit
import Observation
import SwiftUI

/// The formats you starred, shared by Global Stats and Home's Popular on Showdown. Kept by Smogon's
/// format ID, so a favorite that drops out of a month's statistics stays saved and lights up again
/// when Smogon publishes it.
@Observable
@MainActor
final class FavoriteFormats {
    static let shared = FavoriteFormats()
    private static let key = SharedContainer.DefaultsKey.favoriteFormats

    private(set) var ids: [String]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = SharedContainer.defaults ?? .standard) {
        self.defaults = defaults
        ids = defaults.stringArray(forKey: Self.key) ?? []
    }

    func contains(_ id: String) -> Bool { ids.contains(id) }

    /// Stars or unstars a format; new favorites go to the end, in the order they were starred.
    func toggle(_ id: String) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
        defaults.set(ids, forKey: Self.key)
    }

    /// What to say about a favorite that isn't in `month`'s statistics.
    static func unavailableNote(month: String?) -> String {
        month.map { "Not played in \(UsageStatsModel.displayMonth($0))" } ?? "Not played this month"
    }
}

/// A format control with favorites one tap away: once anything is starred, a menu of the favorites
/// and "All Formats…"; before that, a plain button to the full picker. A favorite missing from this
/// month's statistics stays in the menu, disabled, with the reason.
struct FavoriteFormatMenu<MenuLabel: View>: View {
    var formats: [UsageFormat]
    var selected: String?
    var month: String?
    var onPick: (UsageFormat) -> Void
    var onShowAll: () -> Void
    @ViewBuilder var label: () -> MenuLabel

    @State private var favorites = FavoriteFormats.shared

    var body: some View {
        if favorites.ids.isEmpty || formats.isEmpty {
            Button(action: onShowAll, label: label)
        } else {
            Menu {
                Section("Favorites") {
                    ForEach(favorites.ids, id: \.self) { id in
                        if let format = formats.first(where: { $0.id == id }) {
                            Button {
                                onPick(format)
                            } label: {
                                if id == selected {
                                    Label(format.displayName, systemImage: "checkmark")
                                } else {
                                    Text(format.displayName)
                                }
                            }
                        } else {
                            Button {} label: {
                                Text(UsageFormat.displayName(for: id))
                                Text(FavoriteFormats.unavailableNote(month: month))
                            }
                            .disabled(true)
                        }
                    }
                }
                Button("All Formats…", systemImage: "list.bullet", action: onShowAll)
            } label: {
                label()
            }
        }
    }
}

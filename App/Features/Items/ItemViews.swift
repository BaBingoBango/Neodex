import NeodexKit
import SwiftUI

/// The Item Dex: every battle-relevant item.
struct ItemListView: View {
    @Environment(\.database) private var database
    @State private var searchText = ""
    @State private var category: ItemCategory?
    @State private var includePast = true
    @AppStorage("itemDexLayout") private var showsGrid = false

    private var results: [Item] {
        var items = database.items
        if let category { items = items.filter { $0.category == category } }
        if !includePast { items = items.filter { $0.availability == .current } }
        let query = SearchNormalizer.normalize(searchText)
        if !query.isEmpty {
            items = items.filter { SearchNormalizer.match(SearchNormalizer.normalize($0.name), query: query) != .none }
        }
        return items
    }

    var body: some View {
        Group {
            if showsGrid {
                grid
            } else {
                List(results) { item in
                    NavigationLink(value: AppRoute.item(item.id)) {
                        ItemRow(item: item)
                    }
                    .entryActions(AppRoute.item(item.id))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Items")
        .searchable(text: $searchText, prompt: "Item name")
        .toolbar {
            ToolbarItemGroup(placement: .trailingBar) {
                Button {
                    showsGrid.toggle()
                } label: {
                    Label(showsGrid ? "List" : "Grid", systemImage: showsGrid ? "list.bullet" : "square.grid.3x3")
                }
                Menu {
                    Picker("Category", selection: $category) {
                        Text("All Categories").tag(ItemCategory?.none)
                        ForEach(ItemCategory.allCases) { Text($0.name).tag(ItemCategory?.some($0)) }
                    }
                    Toggle("Include past-generation items", isOn: $includePast)
                } label: {
                    Label("Filter", systemImage: category != nil || !includePast ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .overlay { if results.isEmpty { ContentUnavailableView.search(text: searchText) } }
    }

    /// Every item's sprite, the way the original Neodex laid out the bag.
    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                ForEach(results) { item in
                    NavigationLink(value: AppRoute.item(item.id)) {
                        VStack(spacing: 4) {
                            ItemImage(item: item)
                                .frame(width: 44, height: 44)
                            Text(item.name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(height: 28, alignment: .top)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .entryActions(AppRoute.item(item.id))
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.name)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ItemRow: View {
    var item: Item

    var body: some View {
        HStack(spacing: 12) {
            ItemImage(item: item)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.body.weight(.medium))
                if let summary = item.shortDescription ?? item.description {
                    Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if item.availability != .current {
                Image(systemName: "clock")
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Past generations only")
            }
        }
        .padding(.vertical, 2)
    }
}

/// Everything about one item.
struct ItemDetailView: View {
    @Environment(\.database) private var database
    var item: Item

    /// The hero's height, measured, so the bar knows when the hero's name has scrolled under it.
    @State private var heroHeight: CGFloat = 230
    @State private var scrolledPastHero = false

    var body: some View {
        List {
            Section {
                if let description = item.description { Text(description) }
                if let competitive = item.shortDescription, competitive != item.description {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Competitive Effect").font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
                        Text(competitive)
                    }
                }
                LabeledContent("Category", value: item.category.name)
                LabeledContent("Generation", value: "Gen \(item.generation)")
                if item.availability != .current { LabeledContent("Availability", value: item.availability.name) }
                if let fling = item.flingPower { LabeledContent("Fling power", value: "\(fling)") }
                if let gift = item.naturalGift {
                    LabeledContent("Natural Gift") { HStack { Text("\(gift.basePower)"); TypeBadge(type: gift.type, size: .small) } }
                }
                if let type = item.associatedType {
                    LabeledContent("Type") { NavigationLink(value: AppRoute.type(type)) { TypeBadge(type: type, size: .small) }.buttonStyle(.plain) }
                }
            } header: {
                ItemHero(item: item)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heroHeight = $0 }
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
            }

            if let species = item.megaEvolves, let pokemon = database.pokemon(named: species) {
                Section("Mega Evolves") {
                    pokemonLink(pokemon)
                }
            }
            if let users = item.users, !users.isEmpty {
                Section("Used By") {
                    ForEach(users.compactMap(database.pokemon(named:))) { pokemonLink($0) }
                }
            }
            let requirers = database.pokemon.filter { $0.requiredItems?.contains(item.id) == true }
            if !requirers.isEmpty {
                Section("Enables") {
                    ForEach(requirers) { pokemonLink($0) }
                }
            }
        }
        // The name is the hero's last few lines; once it passes under the bar, the bar takes the title.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > heroHeight - 40
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.2)) { scrolledPastHero = past }
        }
        .navigationTitle(item.name)
        .inlineNavigationTitle()
        .heroNavigationBar(title: item.name, revealed: scrolledPastHero)
        .recordsHistory(.item, id: item.id)
    }

    private func pokemonLink(_ pokemon: Pokemon) -> some View {
        NavigationLink(value: AppRoute.pokemon(pokemon.id)) {
            HStack(spacing: 12) {
                PokemonImage(pokemon: pokemon, kind: .sprite).frame(width: 44, height: 44)
                Text(pokemon.displayName).font(.body.weight(.medium))
                Spacer()
                TypeBadgeRow(types: pokemon.types, size: .small)
            }
        }
        .entryActions(AppRoute.pokemon(pokemon.id))
    }
}

/// The item page's hero: the sprite scaled up pixel for pixel over a glow in its own colour, and the
/// name. Tapping the sprite makes it twitch, just for fun.
private struct ItemHero: View {
    var item: Item

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var twitches = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [ItemTint.color(for: item.id).opacity(0.55), .clear],
                                         center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200, height: 200)
                // Item icons are 24 pixels square, so 120 points is a whole number of screen pixels
                // per icon pixel at every display scale, and the pixel art stays crisp.
                ItemImage(item: item)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
                    .keyframeAnimator(initialValue: Twitch(), trigger: twitches) { sprite, twitch in
                        sprite
                            .scaleEffect(twitch.stretch, anchor: .bottom)
                            .rotationEffect(twitch.angle, anchor: .bottom)
                            .offset(y: twitch.lift)
                    } keyframes: { _ in
                        KeyframeTrack(\.lift) {
                            CubicKeyframe(-18, duration: 0.13)
                            CubicKeyframe(0, duration: 0.13)
                            CubicKeyframe(-5, duration: 0.08)
                            CubicKeyframe(0, duration: 0.09)
                        }
                        KeyframeTrack(\.angle) {
                            CubicKeyframe(.degrees(-11), duration: 0.07)
                            CubicKeyframe(.degrees(9), duration: 0.09)
                            CubicKeyframe(.degrees(-6), duration: 0.09)
                            CubicKeyframe(.degrees(3), duration: 0.08)
                            CubicKeyframe(.zero, duration: 0.1)
                        }
                        KeyframeTrack(\.stretch) {
                            CubicKeyframe(CGSize(width: 0.92, height: 1.1), duration: 0.13)
                            CubicKeyframe(CGSize(width: 1.12, height: 0.88), duration: 0.13)
                            SpringKeyframe(CGSize(width: 1, height: 1), duration: 0.3, spring: .bouncy)
                        }
                    }
            }
            .frame(height: 170)
            .contentShape(Circle())
            .onTapGesture {
                if !reduceMotion { twitches += 1 }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: twitches)
            .accessibilityElement()
            .accessibilityLabel(item.name)
            .accessibilityAddTraits(.isImage)
            Text(item.name)
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                // `Color.primary`, not `.primary`: a section header's grey style would make the
                // hierarchical `.primary` grey too.
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }

    private struct Twitch {
        var lift: CGFloat = 0
        var angle: Angle = .zero
        var stretch = CGSize(width: 1, height: 1)
    }
}

/// An item's colour, from its icon: the average of its pixels, weighted toward the bright and
/// colourful ones so outlines and grey metal don't wash it out.
enum ItemTint {
    private static var cache: [String: Color] = [:]

    static func color(for itemID: String) -> Color {
        if let cached = cache[itemID] { return cached }
        let color = averageColor(itemID) ?? .gray
        cache[itemID] = color
        return color
    }

    private static func averageColor(_ itemID: String) -> Color? {
        guard let image = BundledImageStore.shared.itemImage(itemID),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var red = 0.0, green = 0.0, blue = 0.0, total = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.5 else { continue }
            let r = Double(pixels[index]) / 255 / alpha
            let g = Double(pixels[index + 1]) / 255 / alpha
            let b = Double(pixels[index + 2]) / 255 / alpha
            let brightest = max(r, g, b)
            let weight = (brightest - min(r, g, b)) * brightest + 0.02
            red += r * weight
            green += g * weight
            blue += b * weight
            total += weight
        }
        guard total > 0 else { return nil }
        return Color(red: red / total, green: green / total, blue: blue / total)
    }
}

#if DEBUG
#Preview("List") { PreviewHost { ItemListView() } }

#Preview("Detail") {
    PreviewHost {
        if let item = PokedexDatabase.preview.item(id: "leftovers") { ItemDetailView(item: item) }
    }
}
#endif

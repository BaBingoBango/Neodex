import AVFoundation
import Charts
import NeodexKit
import SwiftUI

/// Everything about one Pokémon: entries, abilities, stats, evolutions, forms, traits, locations, moves and matchups.
struct PokemonDetailView: View {
    @Environment(\.database) private var database
    var pokemon: Pokemon

    @State private var selectedEntryIndex = 0
    @State private var speaker = DexSpeaker()
    /// The header's height, measured, so the bar knows when the header's name has scrolled under it.
    @State private var headerHeight: CGFloat = 560
    @State private var scrolledPastHeader = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PokemonHeader(pokemon: pokemon)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                dexEntrySection
                abilitiesSection
                statsSection
                damageCalcLink
                evolutionSection
                formsSection
                characteristicsSection
                matchupSection
                locationsSection
                movesSection
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        // The name sits about 280 points above the header's bottom edge; once it passes under the
        // bar, the bar takes over the title.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > headerHeight - 280
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.2)) { scrolledPastHeader = past }
        }
        .navigationTitle(pokemon.displayName)
        .inlineNavigationTitle()
        .heroNavigationBar(title: pokemon.displayName, revealed: scrolledPastHeader)
        .recordsHistory(.pokemon, id: pokemon.id)
        .toolbar {
            ToolbarItem(placement: .trailingBar) {
                NavigationLink(value: AppRoute.faceOff(pokemon.id)) {
                    Label("Face-Off", systemImage: "bolt.circle")
                }
            }
            ToolbarItem(placement: .trailingBar) {
                Button {
                    speaker.speak(entry: pokemon.dexEntries.indices.contains(selectedEntryIndex) ? pokemon.dexEntries[selectedEntryIndex].text : nil,
                                  for: pokemon)
                } label: {
                    Label("Read Aloud", systemImage: speaker.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                }
            }
        }
        .onDisappear { speaker.stop() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var dexEntrySection: some View {
        if !pokemon.dexEntries.isEmpty {
            let entries = pokemon.dexEntries
            let index = min(selectedEntryIndex, entries.count - 1)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(entries[index].gamesSummary.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    Spacer()
                    if entries.count > 1 {
                        NavigationLink(value: AppRoute.dexEntries(pokemon.id)) {
                            Label("\(entries.count) entries", systemImage: "book.pages")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                Text(entries[index].text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                if entries.count > 1 {
                    Text("Tap the entry for the next game, or browse them all.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture {
                guard entries.count > 1 else { return }
                withAnimation(.snappy) { selectedEntryIndex = (index + 1) % entries.count }
            }
            .animation(.snappy, value: selectedEntryIndex)
        }
    }

    private var damageCalcLink: some View {
        NavigationLink(value: AppRoute.damageCalculator(attacker: pokemon.id, defender: nil)) {
            HStack(spacing: 12) {
                Image(systemName: "function")
                    .font(.title2)
                    .foregroundStyle(PokemonType.fire.color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Damage Calculator")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Run \(pokemon.displayName)'s attacks against any Pokémon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var abilitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Abilities")
            abilityCard(id: pokemon.abilities.primary, slot: "Ability 1", tint: .blue)
            if let secondary = pokemon.abilities.secondary {
                abilityCard(id: secondary, slot: "Ability 2", tint: .blue)
            }
            if let hidden = pokemon.abilities.hidden {
                abilityCard(id: hidden, slot: "Hidden Ability", tint: .gold)
            }
        }
        .padding(.horizontal)
    }

    private func abilityCard(id: String, slot: LocalizedStringKey, tint: Color) -> some View {
        NavigationLink(value: AppRoute.ability(id)) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(slot)
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(tint)
                    Text(database.ability(id: id)?.name ?? id)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let summary = database.ability(id: id)?.shortDescription {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Base Stats")
            BaseStatsView(stats: pokemon.baseStats)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var evolutionSection: some View {
        let family = database.evolutionFamily(of: pokemon)
        if family.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Evolutions")
                    .padding(.horizontal)
                EvolutionChainView(root: family[0], highlighted: pokemon.speciesID)
            }
        }
    }

    @ViewBuilder
    private var formsSection: some View {
        let forms = database.forms(of: pokemon)
        if forms.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Forms")
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(forms) { form in
                            NavigationLink(value: AppRoute.pokemon(form.id)) {
                                VStack(spacing: 6) {
                                    PokemonImage(pokemon: form, kind: .thumbnail)
                                        .frame(width: 72, height: 72)
                                    Text(form.displayName)
                                        .font(.caption.weight(form.id == pokemon.id ? .bold : .regular))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(width: 96)
                                }
                                .padding(8)
                                .background(form.id == pokemon.id ? pokemon.primaryType.color.opacity(0.18) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                if !pokemon.cosmeticForms.isEmpty {
                    Text("Also appears as: " + pokemon.cosmeticForms.map { $0.replacingOccurrences(of: "\(pokemon.name)-", with: "") }.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
        }
    }

    private var characteristicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Characteristics")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                let height = Measurements.heightParts(pokemon.height)
                let weight = Measurements.weightParts(pokemon.weight)
                let gender = Measurements.genderParts(pokemon.maleRatio)
                InfoTile(systemImage: "ruler", label: "Height", value: height.primary, detail: height.secondary, tint: .blue)
                InfoTile(systemImage: "scalemass", label: "Weight", value: weight.primary, detail: weight.secondary, tint: .blue)
                InfoTile(systemImage: "star", label: "EV Yield", value: Measurements.evYield(pokemon.evYield), tint: .green)
                InfoTile(systemImage: "checkmark.seal", label: "Catch Rate", value: pokemon.catchRate.map(String.init) ?? "—", tint: .green)
                InfoTile(systemImage: "heart", label: "Friendship", value: pokemon.baseFriendship.map(String.init) ?? "—", tint: .pink)
                InfoTile(systemImage: "sparkles", label: "Base Exp.", value: pokemon.baseExperience.map(String.init) ?? "—", tint: .pink)
                InfoTile(systemImage: "person.2", label: "Egg Groups", value: pokemon.eggGroups.isEmpty ? "—" : pokemon.eggGroups.joined(separator: " & "), tint: .yellow)
                InfoTile(systemImage: "arrow.triangle.2.circlepath", label: "Egg Cycles", value: pokemon.hatchCycles.map(String.init) ?? "—", tint: .yellow)
                InfoTile(systemImage: "figure.stand.dress.line.vertical.figure", label: "Gender", value: gender.primary, detail: gender.secondary, tint: .purple)
                InfoTile(systemImage: "chart.line.uptrend.xyaxis", label: "Growth Rate", value: pokemon.growthRate ?? "—", tint: .purple)
                InfoTile(systemImage: "number", label: "Generation", value: "Gen \(pokemon.generation)", tint: .gray)
                InfoTile(systemImage: "trophy", label: "Smogon Tier", value: pokemon.tier ?? "—", tint: .gray)
            }
            if !pokemon.tags.isEmpty || pokemon.availability != .current {
                HStack(spacing: 6) {
                    ForEach(pokemon.tags, id: \.self) { tag in
                        Text(tag).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.yellow.opacity(0.25), in: Capsule())
                    }
                    if pokemon.availability != .current {
                        Text(pokemon.availability.name).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.gray.opacity(0.2), in: Capsule())
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var matchupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("Type Matchups")
                NavigationLink(value: AppRoute.typeMatchup(pokemon.types)) {
                    Label("Details", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                }
            }
            DefensiveProfileView(profile: pokemon.defensiveProfile, compact: true)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var locationsSection: some View {
        if let locations = pokemon.locations, !locations.areas.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Locations")
                Text(locations.game)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 8) {
                    ForEach(locations.areas, id: \.self) { area in
                        Text(area)
                            .font(.footnote)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.background.secondary, in: Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var movesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let learnset = database.learnset(for: pokemon)
            HStack {
                SectionTitle("Moves")
                NavigationLink(value: AppRoute.pokemonMoves(pokemon.id)) {
                    Label("All \(learnset.count)", systemImage: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                }
            }
            let levelUp = learnset.filter { $0.learned(by: .levelUp) }
                .sorted { ($0.levelUpLevel() ?? 0, $0.move.name) < ($1.levelUpLevel() ?? 0, $1.move.name) }
                .prefix(8)
            if levelUp.isEmpty {
                Text("No level-up moves recorded.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(levelUp)) { learned in
                        NavigationLink(value: AppRoute.move(learned.move.id)) {
                            MoveRow(move: learned.move, trailing: learned.levelUpLevel().map { $0 <= 1 ? "Start" : "Lv. \($0)" })
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Hero bar

private extension View {
    /// The Pokémon page's navigation bar: clear over the coloured header, with no background, scroll
    /// edge effect or title, until the header scrolls away. The Mac keeps its window title throughout.
    @ViewBuilder
    func heroNavigationBar(title: String, revealed: Bool) -> some View {
        #if os(iOS)
        self
            .toolbarBackgroundVisibility(revealed ? .automatic : .hidden, for: .navigationBar)
            .scrollEdgeEffectHidden(!revealed, for: .top)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .opacity(revealed ? 1 : 0)
                        .accessibilityHidden(!revealed)
                }
            }
        #else
        self
        #endif
    }
}

// MARK: - Header

/// The hero header: a type-coloured gradient that stretches when you pull down, the dex number,
/// official artwork or Showdown's animated sprite over slowly rippling rings, the name and types,
/// and controls for animation, shiny colouring and the Pokémon's cry.
struct PokemonHeader: View {
    var pokemon: Pokemon

    @AppStorage("showsAnimatedSprites") private var showsSprite = false
    @State private var shiny = false
    @State private var cryPlayer = CryPlayer()

    private var primaryColor: Color { pokemon.primaryType.color }
    private var secondaryColor: Color { (pokemon.secondaryType ?? pokemon.primaryType).color }

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                // Grow upward while the list is pulled down so the colour never runs out above.
                let stretch = max(0, proxy.frame(in: .scrollView).minY)
                LinearGradient(colors: [primaryColor, secondaryColor.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: proxy.size.width, height: proxy.size.height + stretch)
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36, style: .continuous))
                    .offset(y: -stretch)
            }
            .ignoresSafeArea(edges: .top)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text(pokemon.formattedDexNumber)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 104)
                ZStack {
                    HeaderRipples()
                        .frame(width: 280, height: 280)
                    Group {
                        if showsSprite {
                            AnimatedSpriteView(pokemon: pokemon, shiny: shiny, maxHeight: 200)
                        } else {
                            PokemonImage(pokemon: pokemon, kind: .artwork)
                        }
                    }
                    .frame(height: 220)
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .animation(.easeInOut(duration: 0.3), value: showsSprite)
                    SparkleBurst(isOn: shiny)
                        .frame(width: 280, height: 280)
                        .allowsHitTesting(false)
                }
                .frame(height: 220)
                .padding(.top, -40)
                VStack(spacing: 8) {
                    Text(pokemon.displayName)
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        // Each badge opens Type-O-Matic with that type chosen.
                        ForEach(pokemon.types) { type in
                            NavigationLink(value: AppRoute.typeOMatic([type])) {
                                TypeBadge(type: type)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens Type-O-Matic")
                        }
                    }
                    if let genus = pokemon.genus {
                        Text("— \(genus) Pokémon —")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    mediaControls
                        .padding(.top, 6)
                }
                .padding(.horizontal)
                .padding(.bottom, 28)
            }
        }
        .onDisappear { cryPlayer.stop() }
    }

    /// Animate / Shiny / Cry as Liquid Glass pills. The symbols never change, so the pills keep
    /// their width; state shows through tint and symbol effects instead.
    private var mediaControls: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Toggle(isOn: $showsSprite.animation()) {
                    Label("Animate", systemImage: "play.fill")
                }
                Toggle(isOn: $shiny) {
                    Label("Shiny", systemImage: "sparkles")
                        .symbolEffect(.bounce, value: shiny)
                }
                .onChange(of: shiny) {
                    if shiny { showsSprite = true }
                }
                Button {
                    cryPlayer.play(pokemon)
                } label: {
                    Label("Cry", systemImage: "speaker.wave.2.fill")
                        .symbolEffect(.variableColor.iterative, isActive: cryPlayer.isPlaying)
                }
                .disabled(cryPlayer.isLoading || cryPlayer.unavailableID == pokemon.id)
            }
            .toggleStyle(.button)
            .buttonStyle(.glass)
            .font(.subheadline.weight(.semibold))
        }
    }
}

/// Soft rings that drift outward behind the artwork, like a Poké Ball's capture ripple.
/// Still under Reduce Motion.
struct HeaderRipples: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { graphics, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = size.width / 2
                graphics.fill(Path(ellipseIn: CGRect(x: center.x - maxRadius * 0.6, y: center.y - maxRadius * 0.6,
                                                       width: maxRadius * 1.2, height: maxRadius * 1.2)),
                              with: .radialGradient(Gradient(colors: [.white.opacity(0.22), .clear]),
                                                    center: center, startRadius: 0, endRadius: maxRadius * 0.6))
                for ring in 0..<4 {
                    let phase = (time / 7 + Double(ring) / 4).truncatingRemainder(dividingBy: 1)
                    let radius = maxRadius * (0.35 + 0.65 * phase)
                    let opacity = (1 - phase) * 0.3
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    graphics.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)), lineWidth: 1.5)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A short burst of sparkles when shiny is switched on. Skipped under Reduce Motion.
struct SparkleBurst: View {
    var isOn: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    private let duration: TimeInterval = 0.9

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: startedAt == nil)) { context in
            Canvas { graphics, size in
                guard let startedAt else { return }
                let progress = context.date.timeIntervalSince(startedAt) / duration
                guard progress >= 0, progress < 1 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let eased = 1 - pow(1 - progress, 3)
                for index in 0..<14 {
                    let seed = Double(index)
                    let angle = seed / 14 * 2 * .pi + sin(seed * 12.9898) * 0.35
                    let reach = (0.28 + 0.14 * abs(sin(seed * 78.233))) * size.width
                    let point = CGPoint(x: center.x + cos(angle) * reach * eased, y: center.y + sin(angle) * reach * eased)
                    let side = 22 * sin(progress * .pi) * (0.55 + 0.45 * abs(cos(seed * 3.7)))
                    var sparkle = graphics.resolve(Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "star.fill"))
                    sparkle.shading = .color(index.isMultiple(of: 2) ? .yellow : .white)
                    graphics.opacity = 1 - progress
                    graphics.draw(sparkle, in: CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side))
                }
            }
        }
        .accessibilityHidden(true)
        .onChange(of: isOn) { _, newValue in
            if newValue, !reduceMotion { startedAt = .now }
        }
        .task(id: startedAt) {
            guard startedAt != nil else { return }
            try? await Task.sleep(for: .seconds(duration + 0.1))
            startedAt = nil
        }
    }
}

// MARK: - Stats

/// Donut chart plus bars for the six base stats.
struct BaseStatsView: View {
    var stats: StatBlock

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 20) {
                donut.frame(width: 150, height: 150)
                bars
            }
            VStack(spacing: 16) {
                donut.frame(width: 150, height: 150)
                bars
            }
        }
    }

    private var donut: some View {
        Chart(stats.values, id: \.stat) { entry in
            SectorMark(angle: .value(entry.stat.name, entry.value), innerRadius: .ratio(0.64), angularInset: 1.5)
                .foregroundStyle(entry.stat.color)
                .cornerRadius(3)
        }
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 0) {
                Text("TOTAL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(stats.total)")
                    .font(.title.weight(.bold))
                    .monospacedDigit()
            }
        }
        .accessibilityLabel("Base stat total \(stats.total)")
    }

    private var bars: some View {
        VStack(spacing: 8) {
            ForEach(stats.values, id: \.stat) { entry in
                HStack(spacing: 8) {
                    Text(entry.stat.shortName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(entry.stat.color)
                        .frame(width: 64, alignment: .leading)
                    Text("\(entry.value)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(entry.stat.color.opacity(0.18))
                            Capsule().fill(entry.stat.color)
                                .frame(width: geometry.size.width * min(1, Double(entry.value) / 200))
                        }
                    }
                    .frame(height: 10)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Evolution chain

/// Horizontal evolution chain with the method between each stage. Branches stack vertically.
struct EvolutionChainView: View {
    var root: Pokemon
    var highlighted: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 8) {
                EvolutionStage(pokemon: root, highlighted: highlighted)
                EvolutionBranches(pokemon: root, highlighted: highlighted)
            }
            .padding(.horizontal)
        }
    }
}

/// The evolutions of one Pokémon, each followed by its own branches. Recursive by design.
struct EvolutionBranches: View {
    @Environment(\.database) private var database
    var pokemon: Pokemon
    var highlighted: String

    private var next: [(evolution: Evolution, target: Pokemon)] {
        pokemon.evolutions.compactMap { evolution in
            database.pokemon(id: evolution.to).map { (evolution, $0) }
        }
    }

    var body: some View {
        if !next.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(next, id: \.target.id) { entry in
                    HStack(spacing: 8) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.title3.weight(.semibold))
                            Text(entry.evolution.methodDescription)
                                .font(.caption2.weight(.medium))
                                .multilineTextAlignment(.center)
                                .frame(width: 92)
                                .foregroundStyle(.secondary)
                        }
                        EvolutionStage(pokemon: entry.target, highlighted: highlighted)
                        EvolutionBranches(pokemon: entry.target, highlighted: highlighted)
                    }
                }
            }
        }
    }
}

struct EvolutionStage: View {
    var pokemon: Pokemon
    var highlighted: String

    var body: some View {
        NavigationLink(value: AppRoute.pokemon(pokemon.id)) {
            VStack(spacing: 4) {
                PokemonImage(pokemon: pokemon, kind: .thumbnail)
                    .frame(width: 84, height: 84)
                Text(pokemon.displayName)
                    .font(.caption.weight(pokemon.id == highlighted ? .bold : .regular))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 96)
            }
            .padding(6)
            .background(pokemon.id == highlighted ? pokemon.primaryType.color.opacity(0.18) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Speech

/// Reads a Pokédex entry aloud, like the classic Pokédex.
@Observable
@MainActor
final class DexSpeaker {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false

    func speak(entry: String?, for pokemon: Pokemon) {
        if synthesizer.isSpeaking {
            stop()
            return
        }
        let types = pokemon.types.map(\.name)
        let typeText = types.count == 2 ? "A \(types[0]) and \(types[1]) type." : "A \(types[0]) type."
        let genus = pokemon.genus.map { "The \($0) Pokémon." } ?? ""
        let text = "\(pokemon.displayName). \(genus) \(typeText) \(entry ?? "")"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        isSpeaking = true
        Task { [weak self] in
            while let self, synthesizer.isSpeaking { try? await Task.sleep(for: .milliseconds(250)) }
            self?.isSpeaking = false
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

// MARK: - Flow layout

/// Wraps its children onto as many rows as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#if DEBUG
#Preview("Charizard") {
    PreviewHost { PokemonDetailView(pokemon: PokedexDatabase.preview.previewPokemon("Charizard")) }
}

#Preview("Ogerpon-Wellspring") {
    PreviewHost { PokemonDetailView(pokemon: PokedexDatabase.preview.previewPokemon("Ogerpon-Wellspring")) }
}

#Preview("Eevee") {
    PreviewHost { PokemonDetailView(pokemon: PokedexDatabase.preview.previewPokemon("Eevee")) }
}
#endif

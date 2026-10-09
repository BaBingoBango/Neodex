import NeodexKit
import SwiftUI

/// Showdown-style damage calculations between two sets, in both directions.
struct DamageCalculatorView: View {
    @Environment(\.database) private var database
    var initialAttackerID: Pokemon.ID? = nil
    var initialDefenderID: Pokemon.ID? = nil

    @State private var model = DamageCalcModel()
    @State private var editing: CalcRole?
    @State private var picking: CalcRole?

    private var isReady: Bool { model.attacker.member != nil && model.defender.member != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sides
                if isReady {
                    fieldSection
                    results(for: .attacker)
                    results(for: .defender)
                } else {
                    ContentUnavailableView("Pick Two Pokémon", systemImage: "function",
                                           description: Text("Choose an attacker and a defender. Tap a card again to edit its set, stat stages, status and HP."))
                        .padding(.top, 12)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Damage Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Swap", systemImage: "arrow.left.arrow.right") {
                    withAnimation { model.swap() }
                }
                .disabled(model.attacker.member == nil && model.defender.member == nil)
            }
        }
        .sheet(item: $picking) { role in
            PokemonPickerSheet(title: role == .attacker ? "Attacker" : "Defender") { pokemon in
                model[role] = CalcSide.make(pokemon, database: database)
            }
        }
        .navigationDestination(item: $editing) { role in
            CalcSideEditorView(role: role, side: Binding(get: { model[role] }, set: { model[role] = $0 }))
        }
        .task { seedIfNeeded() }
    }

    // MARK: Sides

    private var sides: some View {
        HStack(alignment: .top, spacing: 12) {
            sideCard(.attacker)
            sideCard(.defender)
        }
        .padding(.horizontal)
    }

    private func sideCard(_ role: CalcRole) -> some View {
        let side = model[role]
        let pokemon = side.pokemon(in: database)
        return Button {
            if pokemon == nil { picking = role } else { editing = role }
        } label: {
            VStack(spacing: 8) {
                Text(role.title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(role == .attacker ? .red : .blue)
                if let pokemon {
                    PokemonImage(pokemon: pokemon, kind: .sprite)
                        .frame(width: 72, height: 72)
                    Text(pokemon.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.center)
                    TypeBadgeRow(types: pokemon.types, size: .small)
                    Text(side.summary(in: database))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.tint)
                        .frame(height: 72)
                    Text("Choose")
                        .font(.headline)
                        .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .top)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Change Pokémon", systemImage: "arrow.triangle.2.circlepath") { picking = role }
            if pokemon != nil {
                Button("Edit Set", systemImage: "slider.horizontal.3") { editing = role }
                Button("Clear", systemImage: "xmark.circle", role: .destructive) { model[role] = CalcSide() }
            }
        }
        .accessibilityLabel("\(role.title): \(pokemon?.displayName ?? "none chosen")")
    }

    // MARK: Field

    private var fieldSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Field")
            VStack(spacing: 0) {
                fieldRow("Weather", systemImage: "cloud.sun") {
                    Picker("Weather", selection: $model.weather) {
                        ForEach(Weather.allCases) { Text($0.name).tag($0) }
                    }
                }
                Divider().padding(.leading, 44)
                fieldRow("Terrain", systemImage: "square.stack.3d.up") {
                    Picker("Terrain", selection: $model.terrain) {
                        ForEach(Terrain.allCases) { Text($0.name).tag($0) }
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            FlowLayout(spacing: 8) {
                fieldToggle("Doubles", "person.2", $model.isDoubles)
                fieldToggle("Critical Hit", "scope", $model.isCritical)
                fieldToggle("Gravity", "arrow.down.to.line", $model.gravity)
                fieldToggle("Reflect", "shield.lefthalf.filled", $model.defender.reflect)
                fieldToggle("Light Screen", "shield.righthalf.filled", $model.defender.lightScreen)
                fieldToggle("Aurora Veil", "snowflake", $model.defender.auroraVeil)
            }
            Text("Screens belong to the defender. Stat stages, status and HP are set on each Pokémon's card.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func fieldRow<Content: View>(_ title: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.medium))
            Spacer()
            content()
                .pickerStyle(.menu)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func fieldToggle(_ title: LocalizedStringKey, _ systemImage: String, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .font(.caption.weight(.semibold))
    }

    // MARK: Results

    private func results(for role: CalcRole) -> some View {
        let lines = model.lines(from: role, database: database)
        let name = model[role].pokemon(in: database)?.name ?? role.title
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("\(name) attacks")
            if lines.isEmpty {
                Text("No attacking moves chosen. Tap the \(role.title.lowercased()) card to add some.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lines) { line in
                    CalcLineCard(line: line)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: Seeding

    private func seedIfNeeded() {
        if let handoff = DamageCalcModel.handoff {
            if let member = handoff.attacker { model.attacker = CalcSide(member: member) }
            if let member = handoff.defender { model.defender = CalcSide(member: member) }
            DamageCalcModel.handoff = nil
        }
        if model.attacker.member == nil, let id = initialAttackerID, let pokemon = database.pokemon(id: id) {
            model.attacker = CalcSide.make(pokemon, database: database)
        }
        if model.defender.member == nil, let id = initialDefenderID, let pokemon = database.pokemon(id: id) {
            model.defender = CalcSide.make(pokemon, database: database)
        }
    }
}

/// One move's damage: range, percentage bar, KO chance and the full Showdown line.
struct CalcLineCard: View {
    var line: CalcLine

    private var result: DamageResult { line.result }
    private var summary: String { result.summary(moveName: line.move.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TypeBadge(type: result.moveType, size: .small)
                Text(line.move.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Image(systemName: result.category.systemImage)
                    .foregroundStyle(result.category.color)
                    .accessibilityLabel(result.category.name)
                Text(result.basePower > 0 ? "\(result.basePower) BP" : "—")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if result.isImmune {
                Text(result.effectiveness == 0 ? "No effect" : "No damage")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(result.minDamage)–\(result.maxDamage)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text("\(percent(result.minPercent)) – \(percent(result.maxPercent))%")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    if let effectiveness = effectivenessText {
                        Text(effectiveness)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(result.effectiveness > 1 ? .green : .red)
                    }
                }
                DamageBar(minPercent: result.minPercent, maxPercent: result.maxPercent)
                Text(result.koChance.text.prefix(1).uppercased() + result.koChance.text.dropFirst())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(koColor)
            }
            Text(summary)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contextMenu {
            Button("Copy Calc", systemImage: "doc.on.doc") { UIPasteboard.general.string = summary }
        }
    }

    private var effectivenessText: String? {
        switch result.effectiveness {
        case 4: "4× damage"
        case 2: "2× damage"
        case 0.5: "½× damage"
        case 0.25: "¼× damage"
        default: nil
        }
    }

    private var koColor: Color {
        switch result.koChance.hits {
        case 1: .red
        case 2: .orange
        default: .secondary
        }
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}

/// The defender's HP bar with the damage range painted over it.
struct DamageBar: View {
    var minPercent: Double
    var maxPercent: Double

    private var color: Color { maxPercent >= 100 ? .red : maxPercent >= 50 ? .orange : .green }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(color.opacity(0.35)).frame(width: width * min(1, maxPercent / 100))
                Capsule().fill(color).frame(width: width * min(1, minPercent / 100))
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    PreviewHost { DamageCalculatorView(initialAttackerID: "garchomp", initialDefenderID: "greattusk") }
}
#endif

import NeodexKit
import SwiftUI

/// The Nature guide: all 25 natures with their stat effects and flavor preferences.
struct NatureListView: View {
    @Environment(\.database) private var database
    @State private var increased: Stat?
    @State private var decreased: Stat?

    private var results: [Nature] {
        database.natures.filter { nature in
            (increased == nil || nature.increased == increased) && (decreased == nil || nature.decreased == decreased)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Raises", selection: $increased) {
                    Text("Any stat").tag(Stat?.none)
                    ForEach(Stat.allCases.filter { $0 != .hp }) { Text($0.shortName).tag(Stat?.some($0)) }
                }
                Picker("Lowers", selection: $decreased) {
                    Text("Any stat").tag(Stat?.none)
                    ForEach(Stat.allCases.filter { $0 != .hp }) { Text($0.shortName).tag(Stat?.some($0)) }
                }
            }
            Section("\(results.count) natures") {
                ForEach(results) { nature in
                    NavigationLink(value: AppRoute.nature(nature.id)) {
                        HStack {
                            Text(nature.name).font(.body.weight(.medium))
                            Spacer()
                            Text(nature.summary)
                                .font(.subheadline.monospaced())
                                .foregroundStyle(nature.isNeutral ? .secondary : .primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Natures")
    }
}

struct NatureDetailView: View {
    var nature: Nature

    var body: some View {
        List {
            Section {
                if nature.isNeutral {
                    Text("\(nature.name) is a neutral nature: it has no effect on stats.")
                } else if let increased = nature.increased, let decreased = nature.decreased {
                    LabeledContent("Raises") { Text("\(increased.name) ×1.1").foregroundStyle(.green) }
                    LabeledContent("Lowers") { Text("\(decreased.name) ×0.9").foregroundStyle(.red) }
                }
            } header: {
                Text(nature.name)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
            }
            if let liked = nature.likedFlavor, let disliked = nature.dislikedFlavor {
                Section("Berry Flavors") {
                    LabeledContent("Likes", value: liked.name)
                    LabeledContent("Dislikes", value: disliked.name)
                }
            }
            Section("Stat Table") {
                ForEach(Stat.allCases.filter { $0 != .hp }) { stat in
                    LabeledContent(stat.name) {
                        Text("×\(nature.modifier(for: stat).formatted(.number.precision(.fractionLength(1))))")
                            .monospacedDigit()
                            .foregroundStyle(nature.modifier(for: stat) > 1 ? .green : nature.modifier(for: stat) < 1 ? .red : .secondary)
                    }
                }
            }
        }
        .navigationTitle(nature.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

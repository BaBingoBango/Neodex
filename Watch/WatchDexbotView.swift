import NeodexKit
import SwiftUI

/// Dexbot on the wrist. The question is dictated here; the iPhone runs Apple Intelligence and the
/// answer comes back in a sentence or two, so it works even with the phone in a pocket.
struct WatchDexbotView: View {
    var database: PokedexDatabase
    @Environment(PhoneLink.self) private var link

    @State private var question = ""
    @State private var isAsking = false
    @State private var errorText: String?
    @State private var exchanges = WatchDexbotExchange.load()

    private var pick: Pokemon? { DailyPick.pokemonOfTheDay(database.species) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Ask Dexbot…", text: $question)
                    .submitLabel(.send)
                    .onSubmit(ask)
                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                }
                if isAsking {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Asking your iPhone…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                } else if exchanges.isEmpty {
                    suggestions
                }
                ForEach(exchanges) { exchange in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exchange.question)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(exchange.answer)
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .watchCard()
                }
            }
            .padding(.horizontal, 4)
        }
        .contentMargins(.bottom, 44, for: .scrollContent)
        .navigationTitle("Dexbot")
        .containerBackground(WatchTheme.dexbot, for: .navigation)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if !exchanges.isEmpty {
                    Button("Clear", systemImage: "trash") {
                        withAnimation(.snappy) { exchanges = [] }
                        WatchDexbotExchange.save([])
                    }
                    .accessibilityLabel("Clear the conversation")
                }
                Spacer()
                Button("Ask", systemImage: "arrow.up.circle.fill", action: ask)
                    .buttonStyle(.glassProminent)
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || isAsking)
                    .accessibilityLabel("Ask Dexbot")
            }
        }
    }

    /// One-tap questions, so the first ask needs no dictation.
    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dictate a question, or try one of these. Your iPhone's Dexbot answers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let pick {
                suggestion("What is \(pick.displayName) weak to?")
                suggestion("Tell me about \(pick.displayName).")
            }
            if !link.teams.isEmpty {
                suggestion("What does my team struggle against?")
            } else {
                suggestion("Which Pokémon has the highest Speed?")
            }
        }
        .padding(.horizontal, 4)
    }

    private func suggestion(_ text: String) -> some View {
        Button(text) {
            question = text
            ask()
        }
        .buttonStyle(.glass)
        .font(.footnote)
    }

    private func ask() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isAsking else { return }
        isAsking = true
        errorText = nil
        Task {
            defer { isAsking = false }
            do {
                let answer = try await link.ask(text)
                withAnimation(.snappy) {
                    exchanges.insert(WatchDexbotExchange(question: text, answer: answer), at: 0)
                    exchanges = Array(exchanges.prefix(WatchDexbotExchange.kept))
                }
                WatchDexbotExchange.save(exchanges)
                question = ""
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

/// One question and its answer, kept on the watch so the page remembers the conversation.
struct WatchDexbotExchange: Codable, Identifiable {
    var id = UUID()
    var question: String
    var answer: String
    var date = Date()

    static let kept = 8
    private static let key = "dexbotExchanges"

    static func load() -> [WatchDexbotExchange] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([WatchDexbotExchange].self, from: data)) ?? []
    }

    static func save(_ exchanges: [WatchDexbotExchange]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(exchanges), forKey: key)
    }
}

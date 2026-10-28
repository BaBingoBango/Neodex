import SwiftData
import SwiftUI

/// Dexbot's tab: every chat, newest first and grouped by day, with search and a compose button.
struct DexbotConversationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DexbotConversation.updatedAt, order: .reverse) private var conversations: [DexbotConversation]

    /// Only the Dexbot tab's own list opens questions asked from elsewhere, so a copy pushed from
    /// Home doesn't open them too.
    var opensAskedQuestions = false

    @State private var router = DeepLinkRouter.shared
    @State private var searchText = ""
    @State private var composing = false
    /// A question from elsewhere in the app (Scope Lens's "Ask Dexbot"), opened as a new chat.
    @State private var asked: DexbotPrompt?
    @State private var pendingDelete: DexbotConversation?

    private struct DaySection: Identifiable {
        var title: String
        var conversations: [DexbotConversation]
        var id: String { title }
    }

    private var sections: [DaySection] {
        let now = Date.now
        var sections: [DaySection] = []
        for conversation in conversations where matches(conversation) {
            let title = Self.sectionTitle(for: conversation.updatedAt, now: now)
            if sections.last?.title == title {
                sections[sections.count - 1].conversations.append(conversation)
            } else {
                sections.append(DaySection(title: title, conversations: [conversation]))
            }
        }
        return sections
    }

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.conversations) { conversation in
                        NavigationLink {
                            DexbotView(conversation: conversation)
                        } label: {
                            row(conversation)
                        }
                        .navigationLinkIndicatorVisibility(.hidden)
                        .swipeActions {
                            Button("Delete", systemImage: "trash") { pendingDelete = conversation }
                                .tint(.red)
                        }
                        .contextMenu {
                            Button("Delete Chat", systemImage: "trash", role: .destructive) { pendingDelete = conversation }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if conversations.isEmpty {
                emptyState
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search Conversations")
        .navigationTitle("Dexbot")
        .toolbar {
            ToolbarItem(placement: .trailingBar) {
                Button("New Chat", systemImage: "square.and.pencil") { composing = true }
            }
        }
        .navigationDestination(isPresented: $composing) { DexbotView() }
        .navigationDestination(item: $asked) { DexbotView(initialPrompt: $0.question) }
        .confirmationDialog("Delete this chat?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { conversation in
            Button("Delete Chat", role: .destructive) { delete(conversation) }
        } message: { _ in
            Text("Dexbot will forget this conversation. This can't be undone.")
        }
        .onChange(of: router.pendingDexbotQuestion, initial: true) { _, question in
            guard opensAskedQuestions, let question else { return }
            router.pendingDexbotQuestion = nil
            asked = DexbotPrompt(question: question)
        }
    }

    private func row(_ conversation: DexbotConversation) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(conversation.title)
                .font(.headline)
                .lineLimit(1)
            if let preview = Self.preview(of: conversation.messages) {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var emptyState: some View {
        if let reason = DexbotEngine.unavailableReason {
            DexbotUnavailableView(reason: reason)
        } else {
            ContentUnavailableView {
                Label {
                    Text("No Conversations Yet")
                } icon: {
                    DexbotAvatar(size: 64)
                }
            } description: {
                Text("Ask Dexbot about Pokémon, moves, matchups, Smogon stats or your teams.")
            } actions: {
                Button("Start a Chat") { composing = true }
                    .buttonStyle(.glassProminent)
            }
        }
    }

    private func matches(_ conversation: DexbotConversation) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return conversation.title.localizedStandardContains(query)
            || conversation.messages.contains { $0.text.localizedStandardContains(query) }
    }

    private func delete(_ conversation: DexbotConversation) {
        DexbotModel.shared.forget(conversation)
        modelContext.delete(conversation)
    }

    /// "Today", "Yesterday", a weekday within the last week, then the month ("September", or
    /// "September 2025" in an earlier year).
    nonisolated static func sectionTitle(for date: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "Today"
        case 1: return "Yesterday"
        case 2..<7: return date.formatted(.dateTime.weekday(.wide))
        default:
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            return sameYear ? date.formatted(.dateTime.month(.wide)) : date.formatted(.dateTime.month(.wide).year())
        }
    }

    /// Dexbot's latest reply (or the latest message) as one line of plain text.
    nonisolated static func preview(of messages: [DexbotMessage]) -> String? {
        guard let message = messages.last(where: { $0.role == .dexbot }) ?? messages.last else { return nil }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let plain = (try? AttributedString(markdown: message.text, options: options)).map { String($0.characters) } ?? message.text
        let line = plain.split(whereSeparator: \.isNewline).joined(separator: " ")
        return line.isEmpty ? nil : String(line.prefix(160))
    }
}

/// A question to open as a new chat (Scope Lens's "Ask Dexbot" on the Mac).
struct DexbotPrompt: Hashable, Identifiable {
    var question: String
    var id: String { question }
}

#if DEBUG
#Preview { PreviewHost { NavigationStack { DexbotConversationsView() } } }
#endif

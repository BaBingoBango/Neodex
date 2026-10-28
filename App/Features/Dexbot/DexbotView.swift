import NeodexKit
import SwiftData
import SwiftUI

/// Chat with Dexbot: a Pokémon expert that answers from Neodex's own data.
struct DexbotView: View {
    @Environment(\.database) private var database
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The saved chat on screen, by ID so a chat deleted elsewhere is never read; a new chat has
    /// none until its first message saves it.
    @State private var conversationID: UUID?
    @State private var title: String
    private let initialPrompt: String?
    private let start: Start?

    /// How a new chat opened from Home begins.
    enum Start: String, Identifiable {
        case typing, listening
        var id: String { rawValue }
    }

    @State private var model = DexbotModel.shared
    @State private var voice = DexbotVoice()
    @State private var draft = ""
    @State private var confirmingDelete = false
    @State private var showingSettings = false
    /// The model's chat this screen started, so it only adopts the conversation its own first message saves.
    @State private var chatID: UUID?
    @State private var sentInitialPrompt = false
    @State private var didStart = false
    @FocusState private var inputFocused: Bool

    /// Opens a saved chat, or a new one that can start by sending `initialPrompt`, or by putting the
    /// cursor in the text field or listening (`start`).
    init(conversation: DexbotConversation? = nil, initialPrompt: String? = nil, start: Start? = nil) {
        _conversationID = State(initialValue: conversation?.id)
        _title = State(initialValue: conversation?.title ?? "New Chat")
        self.initialPrompt = initialPrompt
        self.start = start
    }

    var body: some View {
        Group {
            if let reason = DexbotEngine.unavailableReason {
                DexbotUnavailableView(reason: reason)
            } else {
                chat
            }
        }
        .navigationTitle(title)
        .inlineNavigationTitle()
        .toolbar { toolbarContent }
        .confirmationDialog("Delete this chat?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Chat", role: .destructive) {
                model.deleteConversation()
                dismiss()
            }
        } message: {
            Text("Dexbot will forget this conversation. This can't be undone.")
        }
        .onAppear(perform: open)
        .sheet(isPresented: $showingSettings, onDismiss: model.refreshPreferences) { DexbotSettingsSheet() }
        .onChange(of: model.conversation?.id) { _, id in
            guard conversationID == nil, let id, model.chatID == chatID else { return }
            conversationID = id
            title = model.conversation?.title ?? title
        }
        .onChange(of: model.pendingSpeech) { _, text in
            guard let text else { return }
            model.clearPendingSpeech()
            voice.speak(text)
        }
        .onChange(of: voice.finishedTranscript) { _, transcript in
            guard let transcript else { return }
            voice.consumeTranscript()
            Task { await model.send(transcript, spoken: true) }
        }
        .onDisappear { voice.stopAll() }
    }

    // MARK: Chat

    private var chat: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if model.messages.isEmpty { intro }
                ForEach(model.messages) { message in
                    DexbotBubble(message: message)
                }
                if model.isResponding, model.respondingConversationID == model.conversation?.id {
                    DexbotBubble(message: DexbotMessage(role: .dexbot, text: model.streamingText), isStreaming: true)
                }
                if voice.isListening {
                    listeningBubble
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        // Keeps the newest bubble in view as a reply streams in, without scrolling by hand on every token.
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .background(Color.groupedBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) { inputBar }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                DexbotAvatar(size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi, I'm Dexbot.").font(.title3.weight(.bold))
                    Text("Ask me anything about Pokémon, moves, matchups, Smogon stats or your teams. Everything I say comes from Neodex's own data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            FlowLayout(spacing: 8) {
                ForEach(DexbotEngine.suggestions, id: \.self) { suggestion in
                    Button(suggestion) { Task { await model.send(suggestion) } }
                        .buttonStyle(.bordered)
                        .font(.subheadline)
                }
            }
            let source = DexbotEngine.sourceDescription
            Label(source.text, systemImage: source.systemImage)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 8)
    }

    private var listeningBubble: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, isActive: true)
                Text(voice.liveTranscript.isEmpty ? "Listening…" : voice.liveTranscript)
                    .font(.body)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.white)
        }
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let errorText = voice.errorText {
                Label(errorText, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask Dexbot…", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onSubmit(sendDraft)
                    .submitLabel(.send)
                if draft.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        if voice.isListening { voice.stopListening() } else { voice.startListening() }
                    } label: {
                        Image(systemName: voice.isListening ? "stop.circle.fill" : "mic.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(voice.isListening ? .red : .accentColor)
                    .disabled(model.isResponding)
                    .accessibilityLabel(voice.isListening ? "Stop listening" : "Ask by voice")
                } else {
                    Button(action: sendDraft) {
                        Image(systemName: "arrow.up")
                            .font(.title3.weight(.bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(model.isResponding)
                    .accessibilityLabel("Send")
                }
            }
        }
        .animation(.default, value: voice.errorText)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func sendDraft() {
        let text = draft
        draft = ""
        Task { await model.send(text) }
    }

    /// Points the shared model at this screen's chat; another Dexbot screen may have switched it.
    private func open() {
        model.configure(database: database, context: modelContext)
        if let conversationID {
            if let conversation = model.storedConversation(conversationID) {
                model.resume(conversation)
                return
            }
            // Deleted from the conversations list while this screen was in the background.
            self.conversationID = nil
            title = "New Chat"
        }
        if chatID != model.chatID {
            model.startNewChat()
            chatID = model.chatID
        }
        if let initialPrompt, !initialPrompt.isEmpty, !sentInitialPrompt {
            sentInitialPrompt = true
            Task { await model.send(initialPrompt) }
        }
        if let start, !didStart {
            didStart = true
            switch start {
            case .typing:
                // Focus taken while a sheet is still sliding up doesn't bring the keyboard.
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    inputFocused = true
                }
            case .listening:
                voice.startListening()
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .trailingBar) {
            Menu {
                Picker("Answers From", systemImage: "cpu", selection: Binding(get: { model.backend }, set: { model.preferredBackend = $0 })) {
                    if DexbotEngine.isOnDeviceAvailable {
                        Label("Apple Intelligence", systemImage: "apple.intelligence").tag(DexbotEngine.Backend.onDevice)
                    }
                    if model.isPrivateCloudAvailable {
                        Label("Private Cloud Compute", systemImage: "icloud").tag(DexbotEngine.Backend.privateCloud)
                    }
                    if DexbotClaude.hasKey {
                        Label(DexbotClaude.model.name, systemImage: "sparkle").tag(DexbotEngine.Backend.claude)
                    }
                }
                .pickerStyle(.menu)
                Button("Dexbot Settings…", systemImage: "gearshape") { showingSettings = true }
                Toggle("Speak Replies", systemImage: "speaker.wave.2", isOn: $voice.speaksReplies)
                if conversationID != nil {
                    Divider()
                    Button("Delete Chat", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

}

/// Shown instead of Dexbot where Apple Intelligence isn't available and there's no Claude key.
struct DexbotUnavailableView: View {
    var reason: String
    @State private var showingSettings = false

    var body: some View {
        ContentUnavailableView {
            Label("Dexbot Needs Apple Intelligence", systemImage: "apple.intelligence")
        } description: {
            Text(reason + "\n\nOr Dexbot can use Claude with your own Anthropic API key.")
        } actions: {
            Button("Use Claude", systemImage: "key") { showingSettings = true }
                .buttonStyle(.glassProminent)
        }
        .sheet(isPresented: $showingSettings, onDismiss: DexbotModel.shared.refreshPreferences) { DexbotSettingsSheet() }
    }
}

/// One message bubble; Dexbot's are rendered as Markdown.
struct DexbotBubble: View {
    var message: DexbotMessage
    var isStreaming = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 48)
            } else {
                DexbotAvatar(size: 28)
            }
            Group {
                if isStreaming, message.text.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle().fill(.secondary).frame(width: 7, height: 7)
                                .symbolEffect(.pulse)
                                .opacity(0.6)
                        }
                    }
                    .padding(.vertical, 6)
                } else {
                    Text(attributed(message.text))
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isUser ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.secondaryGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(isUser ? .white : .primary)
            if !isUser { Spacer(minLength: 32) }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { Clipboard.string = message.text }
        }
    }

    private func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

/// Dexbot's face: a Poké Ball in a speech-bubble tint.
struct DexbotAvatar: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            PokeBallIcon().frame(width: size * 0.56, height: size * 0.56)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview { PreviewHost { DexbotView() } }
#endif

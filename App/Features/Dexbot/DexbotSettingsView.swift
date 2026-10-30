import SwiftUI

/// Where Dexbot's answers come from: Apple Intelligence, or Claude with the user's own Anthropic API key.
struct DexbotSettingsView: View {
    @State private var preferred = DexbotEngine.preferredBackend
    @State private var claudeModel = DexbotClaude.model
    @State private var savedKeyHint = DexbotClaude.APIKey.hint
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        Form {
            Section {
                Picker("Answers From", selection: $preferred) {
                    Text("Apple Intelligence").tag(DexbotEngine.Backend.onDevice)
                    if DexbotEngine.isPrivateCloudAvailable {
                        Text("Private Cloud Compute").tag(DexbotEngine.Backend.privateCloud)
                    }
                    Text("Claude").tag(DexbotEngine.Backend.claude)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Dexbot Answers With")
            } footer: {
                Text(sourceFooter)
            }

            ClaudeKeySection(savedKeyHint: $savedKeyHint, model: claudeModel, focus: $keyFieldFocused,
                             usage: "Your questions and Dexbot's lookups go from this device straight to Anthropic, billed to your Anthropic account.",
                             onSave: { preferred = .claude },
                             onRemove: { if preferred == .claude { preferred = .onDevice } })

            Section("Claude Model") {
                Picker("Model", selection: $claudeModel) {
                    ForEach(DexbotClaude.Model.allCases) { model in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.name)
                            Text(model.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Dexbot")
        .inlineNavigationTitle()
        .onChange(of: preferred) { _, backend in
            DexbotEngine.preferredBackend = backend
            if backend == .claude, savedKeyHint == nil { keyFieldFocused = true }
        }
        .onChange(of: claudeModel) { _, model in
            DexbotClaude.model = model
        }
    }

    private var sourceFooter: String {
        switch preferred {
        case .onDevice:
            "Private and free: Apple Intelligence answers on this device."
        case .privateCloud:
            "Apple's Private Cloud Compute answers when it's available, and this device otherwise."
        case .claude where savedKeyHint == nil:
            "Add your Anthropic API key below to use Claude. Until then, Apple Intelligence answers."
        case .claude:
            "\(claudeModel.name) answers, with Dexbot's lookups into Neodex's own data. If Claude can't be reached, Apple Intelligence answers that question instead."
        }
    }
}

/// The one Claude API key. Dexbot and, on the Mac, Scope Lens's advisor read the same Keychain item, so both
/// settings show this section and a key saved in either works for both.
struct ClaudeKeySection: View {
    /// The saved key's last four characters, shared with the settings around it.
    @Binding var savedKeyHint: String?
    /// The model a key test asks for.
    var model: DexbotClaude.Model
    var focus: FocusState<Bool>.Binding
    /// What the key is used for here, the footer's first sentence.
    var usage: String
    var onSave: () -> Void = {}
    var onRemove: () -> Void = {}

    @State private var draftKey = ""
    @State private var checking = false
    @State private var lastCheck: DexbotClaude.KeyCheck?

    var body: some View {
        Section {
            if let savedKeyHint {
                LabeledContent("API Key", value: savedKeyHint)
                Button("Test Key", systemImage: "checkmark.seal", action: checkSavedKey)
                    .disabled(checking)
                Button("Remove Key", systemImage: "trash", role: .destructive, action: removeKey)
            } else {
                SecureField("API Key", text: $draftKey, prompt: Text("sk-ant-…"))
                    .autocorrectionDisabled()
                    .neverAutocapitalized()
                    .focused(focus)
                    .onSubmit(saveKey)
                Button("Save Key", systemImage: "key", action: saveKey)
                    .disabled(trimmedDraft.isEmpty)
            }
            if checking {
                Label("Checking with Anthropic…", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            } else if let lastCheck {
                checkResult(lastCheck)
            }
        } header: {
            Text("Claude API Key")
        } footer: {
            Text(keyFooter)
        }
        .onChange(of: model) { lastCheck = nil }
        // The other settings tab may have saved or removed the key.
        .onAppear { savedKeyHint = DexbotClaude.APIKey.hint }
    }

    private var trimmedDraft: String { draftKey.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var keyFooter: AttributedString {
        var text = usage + " The key stays in this device's Keychain and is sent only to Anthropic."
        #if os(macOS)
        text += " Dexbot and Scope Lens's advisor share this one key."
        #endif
        text += " [Get an API key](https://platform.claude.com/)"
        return (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    @ViewBuilder
    private func checkResult(_ check: DexbotClaude.KeyCheck) -> some View {
        switch check {
        case .works(let modelName):
            Label("Your key works with \(modelName).", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .rejected:
            Label("Anthropic didn't accept this key.", systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
        case .modelUnavailable:
            Label("This key can't use \(model.name). Pick another model.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .failed(let message):
            Label("Couldn't check the key: \(message)", systemImage: "wifi.exclamationmark")
                .foregroundStyle(.secondary)
        }
    }

    private func saveKey() {
        let key = trimmedDraft
        guard !key.isEmpty, DexbotClaude.APIKey.save(key) else { return }
        draftKey = ""
        savedKeyHint = DexbotClaude.APIKey.hint
        onSave()
        checkSavedKey()
    }

    private func removeKey() {
        DexbotClaude.APIKey.remove()
        savedKeyHint = nil
        lastCheck = nil
        onRemove()
    }

    private func checkSavedKey() {
        guard let key = DexbotClaude.APIKey.saved else { return }
        let model = model
        checking = true
        Task {
            lastCheck = await DexbotClaude.check(key: key, model: model)
            checking = false
        }
    }
}

/// Dexbot's settings in a sheet, opened from the chat.
struct DexbotSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DexbotSettingsView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
        }
        .macSheetFrame()
    }
}

#if DEBUG
#Preview { NavigationStack { DexbotSettingsView() } }
#endif

//
//  AdvisorSettingsView.swift
//  Scope Lens
//
//  Phase 3, m8: Settings pane (⌘,) for the advisor's Anthropic API key.
//  The key is stored in the app's Keychain — never in files or defaults.
//  (ANTHROPIC_API_KEY in the process environment also works for dev runs;
//  the Keychain wins when both are present.)
//

import SwiftUI

public struct AdvisorSettingsView: View {
    @State private var keyField = ""
    @State private var statusLine = ""
    @State private var hasSavedKey = AdvisorClient.savedKey() != nil


    public init() {}
    public var body: some View {
        Form {
            Section {
                Text("“What's the play” advisor")
                    .font(.headline)
                Text("The opt-in LLM layer sends the current battle state to the Claude API (your key, ~a cent per ask). The deterministic matchup math never needs it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField("Anthropic API key (sk-ant-…)", text: $keyField)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Anthropic API key")

                HStack {
                    Button("Save to Keychain") {
                        if AdvisorClient.saveKey(keyField.trimmingCharacters(in: .whitespaces)) {
                            statusLine = "Saved."
                            hasSavedKey = AdvisorClient.savedKey() != nil
                            keyField = ""
                        } else {
                            statusLine = "Keychain save failed."
                        }
                    }
                    .disabled(keyField.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Clear") {
                        AdvisorClient.saveKey("")
                        hasSavedKey = false
                        statusLine = "Cleared."
                    }
                    .disabled(!hasSavedKey)

                    Spacer()

                    Label(hasSavedKey ? "Key saved" :
                          (AdvisorClient.hasKey ? "Using environment key" : "No key"),
                          systemImage: hasSavedKey || AdvisorClient.hasKey
                              ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(hasSavedKey || AdvisorClient.hasKey ? .green : .orange)
                }
                if !statusLine.isEmpty {
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

#Preview {
    AdvisorSettingsView()
}

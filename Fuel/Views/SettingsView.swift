import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        APIKeySettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.orange)
                                .frame(width: 28)

                            Text("GenAI API Keys")
                                .font(.custom("Avenir Next", size: 16))
                        }
                    }
                } header: {
                    Text("Configuration")
                        .font(.custom("Avenir Next", size: 12))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct APIKeySettingsView: View {
    @State private var claudeKey = ""
    @State private var chatgptKey = ""
    @State private var claudeHasExisting = false
    @State private var chatgptHasExisting = false
    @State private var claudeMasked = ""
    @State private var chatgptMasked = ""
    @State private var showingClaudeSaved = false
    @State private var showingChatGPTSaved = false

    private let apiKeyManager = APIKeyManager.shared

    var body: some View {
        List {
            // Claude Section
            Section {
                APIKeyInputRow(
                    provider: .claude,
                    inputKey: $claudeKey,
                    hasExisting: claudeHasExisting,
                    maskedKey: claudeMasked,
                    showingSaved: $showingClaudeSaved,
                    onSave: { saveKey(for: .claude) }
                )
            } header: {
                Text("Claude (Anthropic)")
                    .font(.custom("Avenir Next", size: 12))
            } footer: {
                Text("Get your API key from console.anthropic.com")
                    .font(.custom("Avenir Next", size: 12))
            }

            // ChatGPT Section
            Section {
                APIKeyInputRow(
                    provider: .chatgpt,
                    inputKey: $chatgptKey,
                    hasExisting: chatgptHasExisting,
                    maskedKey: chatgptMasked,
                    showingSaved: $showingChatGPTSaved,
                    onSave: { saveKey(for: .chatgpt) }
                )
            } header: {
                Text("ChatGPT (OpenAI)")
                    .font(.custom("Avenir Next", size: 12))
            } footer: {
                Text("Get your API key from platform.openai.com")
                    .font(.custom("Avenir Next", size: 12))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("GenAI API Keys")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadExistingKeys()
        }
    }

    private func loadExistingKeys() {
        claudeHasExisting = apiKeyManager.hasAPIKey(for: .claude)
        chatgptHasExisting = apiKeyManager.hasAPIKey(for: .chatgpt)
        claudeMasked = apiKeyManager.getMaskedAPIKey(for: .claude) ?? ""
        chatgptMasked = apiKeyManager.getMaskedAPIKey(for: .chatgpt) ?? ""
    }

    private func saveKey(for provider: AIProvider) {
        let key = provider == .claude ? claudeKey : chatgptKey

        if apiKeyManager.saveAPIKey(key, for: provider) {
            // Clear the input
            if provider == .claude {
                claudeKey = ""
                showingClaudeSaved = true
            } else {
                chatgptKey = ""
                showingChatGPTSaved = true
            }
            loadExistingKeys()

            // Hide the saved indicator after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if provider == .claude {
                    showingClaudeSaved = false
                } else {
                    showingChatGPTSaved = false
                }
            }
        }
    }
}

struct APIKeyInputRow: View {
    let provider: AIProvider
    @Binding var inputKey: String
    let hasExisting: Bool
    let maskedKey: String
    @Binding var showingSaved: Bool
    let onSave: () -> Void

    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasExisting && !isEditing {
                // Show masked key with edit option
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundColor(.secondary)

                        Text(maskedKey)
                            .font(.custom("Avenir Next", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    if showingSaved {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Saved")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundColor(.green)
                        }
                        .transition(.opacity)
                    } else {
                        Button("Update") {
                            withAnimation {
                                isEditing = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isFocused = true
                            }
                        }
                        .font(.custom("Avenir Next", size: 14))
                        .fontWeight(.medium)
                    }
                }
            } else {
                // Show input field
                VStack(alignment: .leading, spacing: 8) {
                    if isEditing {
                        HStack {
                            Text("Enter new API Key")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundColor(.secondary)

                            Spacer()

                            Button("Cancel") {
                                withAnimation {
                                    isEditing = false
                                    inputKey = ""
                                }
                            }
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundColor(.red)
                        }
                    } else {
                        Text("API Key")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        SecureField(provider.placeholder, text: $inputKey)
                            .font(.custom("Avenir Next", size: 16))
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($isFocused)

                        if !inputKey.isEmpty {
                            Button(action: {
                                onSave()
                                withAnimation {
                                    isEditing = false
                                }
                            }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                            }
                        }
                    }

                    if showingSaved {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Saved successfully")
                                .font(.custom("Avenir Next", size: 13))
                                .foregroundColor(.green)
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: showingSaved)
    }
}

#Preview {
    SettingsView()
}

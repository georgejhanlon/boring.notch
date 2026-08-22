//
//  ClaudeSettingsView.swift
//  boringNotch
//
//  Settings for the Claude chat tab — the Anthropic API key the in-notch chat
//  uses. Stored in the Keychain (see APIKeyStore), not app preferences.
//

import SwiftUI

struct ClaudeSettings: View {
    @StateObject private var keyStore = APIKeyStore.shared

    var body: some View {
        Form {
            Section {
                SecureField("sk-ant-…", text: $keyStore.apiKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Image(systemName: keyStore.apiKey.hasPrefix("sk-ant-") ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(keyStore.apiKey.hasPrefix("sk-ant-") ? .green : .secondary)
                    Text(keyStore.apiKey.hasPrefix("sk-ant-") ? "Key saved to your Keychain." : "Paste an Anthropic API key to enable the Claude tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Anthropic API Key")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Create a key at")
                        Link("console.anthropic.com/settings/keys",
                             destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                            .foregroundColor(.blue)
                    }
                    Text("The in-notch chat uses this key to talk to Claude (billed as API usage, separate from a Claude.ai subscription). The key is stored securely in your login Keychain, so it never ships with the app.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Claude")
    }
}

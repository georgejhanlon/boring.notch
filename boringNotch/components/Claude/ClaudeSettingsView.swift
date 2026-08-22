//
//  ClaudeSettingsView.swift
//  boringNotch
//
//  Settings for the Claude chat tab — currently the Anthropic API key the
//  in-notch chat uses.
//

import Defaults
import SwiftUI

struct ClaudeSettings: View {
    @Default(.anthropicAPIKey) private var apiKey

    var body: some View {
        Form {
            Section {
                SecureField("sk-ant-…", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Image(systemName: apiKey.hasPrefix("sk-ant-") ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(apiKey.hasPrefix("sk-ant-") ? .green : .secondary)
                    Text(apiKey.hasPrefix("sk-ant-") ? "Key saved." : "Paste an Anthropic API key to enable the Claude tab.")
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
                    Text("The in-notch chat uses this key to talk to Claude (billed as API usage, separate from a Claude.ai subscription). The key is stored in your app preferences.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Claude")
    }
}

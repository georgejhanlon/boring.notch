//
//  EmailSettingsView.swift
//  boringNotch
//
//  Settings for the Email triage tab. Mirrors the Media settings' control
//  configuration: the user arranges which triage actions appear in the row.
//

import Defaults
import SwiftUI

struct EmailSettings: View {
    var body: some View {
        Form {
            Section {
                EmailSlotConfigurationView()
            } header: {
                Text("Triage actions")
            } footer: {
                Text("Customize which actions appear beneath the message. Drag controls from the palette onto a slot, drag slots to reorder, or drop a slot on the trash to clear it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Email")
    }
}

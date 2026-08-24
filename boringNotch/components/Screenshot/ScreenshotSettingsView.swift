//
//  ScreenshotSettingsView.swift
//  boringNotch
//
//  Settings for the Screenshot tab. Kept here (not in the notch UI) per design:
//  the notch tab stays a quick capture surface; preferences live in Settings.
//

import Defaults
import SwiftUI

struct ScreenshotSettings: View {
    @Default(.screenshotSelectionNotchBehavior) private var notchBehavior

    var body: some View {
        Form {
            Section {
                Picker("During a Selection capture", selection: $notchBehavior) {
                    ForEach(ScreenshotSelectionNotchBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
            } header: {
                Text("Notch")
            } footer: {
                Text("Controls the notch while you drag the ⌘⇧4 crosshair selection. Hiding or closing keeps the notch out of the screenshot.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Screenshots")
    }
}

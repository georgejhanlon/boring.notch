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
    @Default(.screenshotFullScreenIncludeNotch) private var fullScreenIncludeNotch

    var body: some View {
        Form {
            Section {
                Picker("During a Selection capture", selection: $notchBehavior) {
                    ForEach(ScreenshotSelectionNotchBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                Toggle("Include the notch in a Full Screen capture", isOn: $fullScreenIncludeNotch)
            } header: {
                Text("Notch")
            } footer: {
                Text("The Selection option controls the notch while you drag the ⌘⇧4 crosshair. For a Full Screen capture, turn the toggle off to hide the notch overlay so it doesn't appear in the shot.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Screenshots")
    }
}

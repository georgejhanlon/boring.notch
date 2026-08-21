//
//  ChecklistSettingsView.swift
//  boringNotch
//
//  Settings pane for the Checklist feature. Mirrors the other settings views
//  (Form / Section / Defaults) and lives in the Checklist feature so it is
//  auto-compiled by the feature's synchronized group.
//

import Defaults
import SwiftUI

struct ChecklistSettings: View {
    @Default(.checklistAlwaysOn) private var alwaysOn
    @Default(.checklistAlwaysOnHeight) private var alwaysOnHeight
    @Default(.checklistArchiveRetention) private var archiveRetention
    @Default(.checklistRecentLength) private var recentLength
    @Default(.checklistAnimationSpeed) private var animationSpeed
    @Default(.checklistDefaultName) private var defaultName

    @State private var showClearConfirmation = false

    var body: some View {
        Form {
            Section {
                // Always-on: custom circular tick control — blue fill with a
                // white checkmark when enabled.
                Button {
                    alwaysOn.toggle()
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(alwaysOn ? Color.blue : Color.clear)
                                .overlay(
                                    Circle()
                                        .stroke(alwaysOn ? Color.blue : Color.secondary, lineWidth: 1.5)
                                )
                                .frame(width: 20, height: 20)
                            if alwaysOn {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        Text("Always-on mode")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Always-on notch height: \(Int(alwaysOnHeight)) px")
                    Slider(value: $alwaysOnHeight, in: 200...600, step: 10)
                }
                .disabled(!alwaysOn)
                .opacity(alwaysOn ? 1 : 0.5)
            } header: {
                Text("Always-on")
            } footer: {
                Text("Keeps the notch enlarged with the full checklist rendered directly beneath it, always visible.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Defaults.Toggle(key: .checklistShowCompleted) {
                    Text("Show completed section")
                }

                Picker("Animation speed", selection: $animationSpeed) {
                    ForEach(ChecklistAnimationSpeed.allCases) { speed in
                        Text(speed.localizedString).tag(speed)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Default checklist name", text: $defaultName)
            } header: {
                Text("Display")
            }

            Section {
                Stepper(value: $archiveRetention, in: 0...1000, step: 10) {
                    Text(archiveRetention == 0
                         ? "Archived checklists to keep: Unlimited"
                         : "Archived checklists to keep: \(archiveRetention)")
                }
                Stepper(value: $recentLength, in: 1...50) {
                    Text("Recent list length: \(recentLength)")
                }
            } header: {
                Text("History")
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Text("Clear current checklist")
                }
                .confirmationDialog(
                    "Clear the current checklist?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) {
                        ChecklistStore.shared.clearCurrent()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The current checklist will be archived, then emptied.")
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Checklist")
    }
}

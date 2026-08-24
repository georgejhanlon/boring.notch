//
//  FocusDNDController.swift
//  boringNotch
//
//  Toggles macOS Do Not Disturb / Focus for the focus timer. Modern macOS has
//  no public API to set Focus directly, so this drives it through the Shortcuts
//  app: the user supplies two shortcuts (default names below) that turn a Focus
//  on and off. If they don't exist the call fails quietly — the timer still runs.
//

import Foundation

@MainActor
final class FocusDNDController {
    static let shared = FocusDNDController()

    /// Names of the user's Shortcuts. Create these in the Shortcuts app with a
    /// single "Set Focus / Do Not Disturb — On/Off" action.
    var onShortcutName = "Turn On Do Not Disturb"
    var offShortcutName = "Turn Off Do Not Disturb"

    /// Tracks the last state we asked for so we don't fire the shortcut twice.
    private var isEnabled = false

    private init() {}

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        run(shortcut: enabled ? onShortcutName : offShortcutName)
    }

    private func run(shortcut: String) {
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", shortcut]
            // Swallow output/errors — a missing shortcut shouldn't disrupt the timer.
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }
}

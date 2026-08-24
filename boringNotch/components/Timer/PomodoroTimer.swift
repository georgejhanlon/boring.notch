//
//  PomodoroTimer.swift
//  boringNotch
//
//  A small focus timer / Pomodoro engine for the notch. Counts down a work
//  phase, then a break, and loops. Also usable as a plain countdown via presets.
//

import AppKit
import Combine
import Defaults
import SwiftUI

@MainActor
final class PomodoroTimer: ObservableObject {
    static let shared = PomodoroTimer()

    enum Phase: String {
        case work, breakTime

        var title: String { self == .work ? "Focus" : "Break" }
        var tint: Color { self == .work ? .claudeOrange : .green }
    }

    @Published private(set) var phase: Phase = .work
    @Published private(set) var remaining: Int = 25 * 60
    @Published private(set) var isRunning = false
    @Published private(set) var completedSessions = 0

    /// Length of each phase in minutes; adjustable from the UI.
    @Published var workMinutes: Int = 25 { didSet { if phase == .work, !isRunning { resetPhaseDuration() } } }
    @Published var breakMinutes: Int = 5 { didSet { if phase == .breakTime, !isRunning { resetPhaseDuration() } } }

    /// Turn on Do Not Disturb while a focus phase is running (persisted).
    @Published var dndDuringFocus: Bool = Defaults[.focusTimerDND] {
        didSet {
            Defaults[.focusTimerDND] = dndDuringFocus
            syncDND()
        }
    }

    private var ticker: AnyCancellable?

    private init() {}

    var totalForPhase: Int { (phase == .work ? workMinutes : breakMinutes) * 60 }
    var progress: Double {
        let total = max(totalForPhase, 1)
        return 1 - Double(remaining) / Double(total)
    }
    var isActive: Bool { isRunning || remaining != totalForPhase }

    var display: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Controls

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        syncDND()
    }

    func pause() {
        isRunning = false
        ticker?.cancel()
        ticker = nil
        syncDND()
    }

    func reset() {
        pause()
        resetPhaseDuration()
    }

    /// Skip to the next phase (work ↔ break) without waiting for the countdown.
    func skip() {
        advancePhase(playedThrough: false)
    }

    func setPreset(minutes: Int) {
        let clamped = min(max(minutes, 1), 180)
        pause()
        phase = .work
        workMinutes = clamped
        remaining = clamped * 60
    }

    /// Nudge the (work) duration for a custom timer, in whole minutes.
    func adjustWork(by delta: Int) {
        setPreset(minutes: workMinutes + delta)
    }

    // MARK: - Internals

    private func resetPhaseDuration() {
        remaining = totalForPhase
    }

    private func tick() {
        guard remaining > 0 else { advancePhase(playedThrough: true); return }
        remaining -= 1
        if remaining == 0 { advancePhase(playedThrough: true) }
    }

    private func advancePhase(playedThrough: Bool) {
        let wasWork = phase == .work
        if wasWork && playedThrough { completedSessions += 1 }
        if playedThrough { NSSound.beep() }
        phase = wasWork ? .breakTime : .work
        resetPhaseDuration()
        // Keep running into the next phase if it played through naturally.
        if !playedThrough { pause() }
        syncDND()
    }

    /// Enable DND only while a focus phase is actively running.
    private func syncDND() {
        let shouldEnable = dndDuringFocus && isRunning && phase == .work
        FocusDNDController.shared.setEnabled(shouldEnable)
    }
}

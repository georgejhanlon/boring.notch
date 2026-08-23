//
//  TimerView.swift
//  boringNotch
//
//  The Timer / Pomodoro tab: a countdown ring with start/pause, reset, skip,
//  and quick presets.
//

import SwiftUI

struct TimerView: View {
    @StateObject private var timer = PomodoroTimer.shared

    private let presets = [5, 15, 25, 45, 60]

    var body: some View {
        HStack(spacing: 18) {
            ring
            VStack(alignment: .leading, spacing: 8) {
                header
                presetRow
                controls
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 7)
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(timer.phase.tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: timer.progress)
            VStack(spacing: 0) {
                Text(timer.display)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(timer.phase.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(timer.phase.tint)
            }
        }
        .frame(width: 108, height: 108)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .foregroundStyle(.white)
            Text("Focus Timer")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            if timer.completedSessions > 0 {
                Label("\(timer.completedSessions)", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.gray)
            }
        }
    }

    private var presetRow: some View {
        HStack(spacing: 5) {
            ForEach(presets, id: \.self) { minutes in
                Button {
                    timer.setPreset(minutes: minutes)
                } label: {
                    Text("\(minutes)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(timer.workMinutes == minutes ? .black : .white)
                        .frame(minWidth: 14)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(timer.workMinutes == minutes ? Color.white : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }

            // Custom: nudge the duration in 5-minute steps.
            HStack(spacing: 2) {
                stepButton("minus") { timer.adjustWork(by: -5) }
                stepButton("plus") { timer.adjustWork(by: 5) }
            }
            .padding(.leading, 2)
        }
    }

    private func stepButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(action: timer.toggle) {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(timer.phase.tint))
            }
            .buttonStyle(.plain)

            controlButton(system: "arrow.counterclockwise", help: "Reset", action: timer.reset)
            controlButton(system: "forward.end.fill", help: "Skip to \(timer.phase == .work ? "break" : "focus")", action: timer.skip)
        }
    }

    private func controlButton(system: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

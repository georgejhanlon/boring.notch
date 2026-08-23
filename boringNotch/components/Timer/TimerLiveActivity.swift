//
//  TimerLiveActivity.swift
//  boringNotch
//
//  Compact countdown shown in the closed notch while a focus timer is running:
//  the time sits just to the left of the physical notch, with a small progress
//  ring on the right.
//

import SwiftUI

struct TimerLiveActivity: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var timer = PomodoroTimer.shared

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(timer.phase.tint)
                Text(timer.display)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 10)

            // Gap for the physical notch.
            Color.clear.frame(width: vm.closedNotchSize.width)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(timer.phase.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 14, height: 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
        }
        .frame(height: vm.effectiveClosedNotchHeight)
    }
}

//
//  ChecklistAlwaysOnStrip.swift
//  boringNotch
//
//  The compact always-on row rendered inside the closed notch: a horizontal
//  strip of dots (one per upcoming item) with a short label beneath each, plus
//  a small trailing chevron to open the full notch. Tapping a dot completes the
//  item — it swooshes off to the leading edge and the next slides in from the
//  trailing edge, without waking the notch.
//

import SwiftUI
import Defaults

struct ChecklistAlwaysOnStrip: View {
    /// Opens the full notch. Kept as a closure so completing an item never does.
    var onOpen: () -> Void = {}

    @StateObject private var store = ChecklistStore.shared
    @Default(.checklistAlwaysOnCount) private var count
    @Default(.checklistAnimationSpeed) private var animationSpeed

    private var visibleItems: [ChecklistItem] {
        Array(store.checklist.activeItems.prefix(max(1, count)))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(visibleItems) { item in
                    dot(for: item)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: animationSpeed.response, dampingFraction: 0.75),
                       value: store.checklist.activeItems)

            Button(action: onOpen) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.gray)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open checklist")
        }
        .frame(maxWidth: .infinity)
    }

    private func dot(for item: ChecklistItem) -> some View {
        Button {
            withAnimation(.spring(response: animationSpeed.response, dampingFraction: 0.75)) {
                store.toggle(item)
            }
        } label: {
            VStack(spacing: 2) {
                Circle()
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.2)
                    .frame(width: 7, height: 7)
                Text(item.text)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 46)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

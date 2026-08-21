//
//  ChecklistAlwaysOnStrip.swift
//  boringNotch
//
//  The compact always-on row rendered inside the closed notch: a narrow strip
//  (about the width of the notch) of evenly-spaced dots, each with a short label
//  that wraps to two lines before truncating, and a small open chevron on the
//  far right. Tapping a dot marks it done in place (grey dot with a tick cutout
//  and struck-through text) and then swooshes it off to the leading edge; the
//  next item slides in from the trailing edge. Ticking never wakes the notch.
//

import SwiftUI
import Defaults

struct ChecklistAlwaysOnStrip: View {
    /// Opens the full notch. Kept as a closure so completing an item never does.
    var onOpen: () -> Void = {}

    @StateObject private var store = ChecklistStore.shared
    @Default(.checklistAlwaysOnCount) private var count
    @Default(.checklistAnimationSpeed) private var animationSpeed

    /// Items shown mid-completion: grey dot + tick, struck-through text, briefly,
    /// before they actually leave the list and swoosh away.
    @State private var completing: Set<UUID> = []

    private var visibleItems: [ChecklistItem] {
        Array(store.checklist.activeItems.prefix(max(1, count)))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            ForEach(visibleItems) { item in
                dot(for: item)
                    .frame(maxWidth: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }

            Button(action: onOpen) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.gray)
                    .frame(width: 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open checklist")
        }
        .animation(.spring(response: animationSpeed.response, dampingFraction: 0.78),
                   value: store.checklist.activeItems)
    }

    private func dot(for item: ChecklistItem) -> some View {
        let isCompleting = completing.contains(item.id)
        return Button {
            complete(item)
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if isCompleting {
                        // Grey dot with a tick "cut out" of it.
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.black, .gray)
                            .font(.system(size: 9, weight: .bold))
                    } else {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.2)
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(width: 9, height: 9)

                Text(item.text)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.gray)
                    .strikethrough(isCompleting, color: .gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Two-stage completion: show the done state in place, then remove it so the
    /// removal transition swooshes it away and the next item slides in.
    private func complete(_ item: ChecklistItem) {
        guard !completing.contains(item.id) else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            _ = completing.insert(item.id)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.spring(response: animationSpeed.response, dampingFraction: 0.78)) {
                store.toggle(item)
            }
            completing.remove(item.id)
        }
    }
}

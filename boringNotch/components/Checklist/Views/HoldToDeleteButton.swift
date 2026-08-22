//
//  HoldToDeleteButton.swift
//  boringNotch
//
//  A trash control that must be held to fire. While held, the bin fills from the
//  bottom with red; releasing early cancels and drains it.
//

import SwiftUI

struct HoldToDeleteButton: View {
    var duration: Double = 2
    var action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Resting bin. Using the filled glyph for both layers means the red
            // simply rises inside the same silhouette — no outline/fill shape jump.
            Image(systemName: "trash.fill")
                .foregroundStyle(.gray.opacity(0.55))

            // Red that fills from the bottom as the hold progresses.
            Image(systemName: "trash.fill")
                .foregroundStyle(.red)
                .mask(
                    GeometryReader { geo in
                        Rectangle()
                            .frame(height: geo.size.height * progress)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                )
        }
        .imageScale(.small)
        .contentShape(Rectangle())
        .scaleEffect(isHolding ? 1.08 : 1)
        .animation(.easeOut(duration: 0.15), value: isHolding)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in cancelHold() }
        )
        .help("Hold to clear the current checklist")
    }

    private func startHold() {
        guard !isHolding else { return }
        isHolding = true
        withAnimation(.linear(duration: duration)) { progress = 1 }

        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            action()
            isHolding = false
            // Snap back without a drain animation once it has fired.
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { progress = 0 }
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        isHolding = false
        // Released early: quickly drain the red back down.
        withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
    }
}

//
//  HoldToDeleteButton.swift
//  boringNotch
//
//  A trash control that must be held for a few seconds to fire. While held, the
//  bin fills from the bottom with colour; releasing early cancels and drains it.
//

import SwiftUI

struct HoldToDeleteButton: View {
    var duration: Double = 3
    var action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Base outline.
            Image(systemName: "trash")
                .foregroundStyle(.gray)

            // Colour that fills from the bottom as the hold progresses.
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
        .scaleEffect(isHolding ? 1.15 : 1)
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
            progress = 0
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        isHolding = false
        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
    }
}

//
//  NotchWindowHeightExpander.swift
//  boringNotch
//
//  The notch lives in a fixed-size borderless window (`windowSize`). The AI chat
//  can be dragged taller than that budget, so this helper grows the window itself
//  by `extraHeight` and keeps its top edge pinned to the top of the screen. When
//  the extra height returns to zero (leaving the chat, or the feature disabled)
//  the window snaps back to its normal size.
//

import AppKit
import SwiftUI

struct NotchWindowHeightExpander: NSViewRepresentable {
    var extraHeight: CGFloat

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ nsView: NSView, context: Context) {
        let target = extraHeight
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            Self.apply(extraHeight: target, to: window)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        if let window = nsView.window {
            apply(extraHeight: 0, to: window)
        }
    }

    /// Resize the window to `windowSize.height + extra` (clamped to the screen)
    /// while keeping the top edge fixed.
    private static func apply(extraHeight: CGFloat, to window: NSWindow) {
        let screen = window.screen ?? NSScreen.main
        // Never grow past the space under the menu bar.
        let maxHeight = (screen?.visibleFrame.height).map { $0 + shadowPadding } ?? .greatestFiniteMagnitude
        let targetHeight = min(windowSize.height + max(0, extraHeight), maxHeight)

        guard abs(window.frame.height - targetHeight) > 0.5 else { return }

        let topY = window.frame.maxY   // keep the current top edge fixed
        var frame = window.frame
        frame.size.height = targetHeight
        frame.origin.y = topY - targetHeight
        window.setFrame(frame, display: true)
    }
}

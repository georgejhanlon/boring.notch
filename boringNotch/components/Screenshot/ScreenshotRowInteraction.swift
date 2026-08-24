//
//  ScreenshotRowInteraction.swift
//  boringNotch
//
//  Mouse layer for a screenshot history row: click to select (⌘/⇧ for many,
//  Finder-style deferred single-select), double-click to open, drag to export
//  the selected files (multi-file via an AppKit dragging session), right-click
//  for a context menu. Kept AppKit so it works without a `List` — the notch's
//  rounded corners rely on transparent SwiftUI content.
//

import AppKit
import SwiftUI

struct ScreenshotRowInteraction: NSViewRepresentable {
    let isSelected: () -> Bool
    let onSelect: (NSEvent.ModifierFlags) -> Void
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let dragURLs: () -> [URL]
    let preview: () -> NSImage?

    func makeNSView(context: Context) -> MouseView {
        let view = MouseView()
        view.owner = self
        return view
    }

    func updateNSView(_ nsView: MouseView, context: Context) {
        nsView.owner = self
    }

    final class MouseView: NSView, NSDraggingSource {
        var owner: ScreenshotRowInteraction?

        private var mouseDownEvent: NSEvent?
        private var pendingSingleSelect = false
        private let dragThreshold: CGFloat = 3

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            pendingSingleSelect = false

            guard let owner else { return }

            if event.clickCount == 2 {
                owner.onOpen()
                return
            }

            let mods = event.modifierFlags
            if mods.contains(.command) || mods.contains(.shift) {
                owner.onSelect(mods)                 // toggle / range immediately
            } else if owner.isSelected() {
                pendingSingleSelect = true            // defer: allow group drag
            } else {
                owner.onSelect([])                    // select just this one
            }
        }

        override func mouseDragged(with event: NSEvent) {
            guard let down = mouseDownEvent else { return }
            let dist = hypot(event.locationInWindow.x - down.locationInWindow.x,
                             event.locationInWindow.y - down.locationInWindow.y)
            guard dist > dragThreshold else { return }
            pendingSingleSelect = false
            mouseDownEvent = nil
            startDrag(with: event)
        }

        override func mouseUp(with event: NSEvent) {
            if pendingSingleSelect { owner?.onSelect([]) }
            pendingSingleSelect = false
            mouseDownEvent = nil
        }

        override func rightMouseDown(with event: NSEvent) {
            guard let owner else { return }
            let menu = NSMenu()
            menu.addItem(withActionTitle: "Open") { owner.onOpen() }
            menu.addItem(withActionTitle: "Show in Finder") { owner.onReveal() }
            menu.addItem(.separator())
            menu.addItem(withActionTitle: "Delete") { owner.onDelete() }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }

        private func startDrag(with event: NSEvent) {
            guard let owner else { return }
            let urls = owner.dragURLs()
            guard !urls.isEmpty else { return }

            let image = owner.preview() ?? NSImage(size: NSSize(width: 40, height: 28))
            let frame = NSRect(origin: .zero, size: image.size)

            let items: [NSDraggingItem] = urls.map { url in
                let item = NSDraggingItem(pasteboardWriter: url as NSURL)
                item.setDraggingFrame(frame, contents: image)
                return item
            }
            beginDraggingSession(with: items, event: event, source: self)
        }

        func draggingSession(_ session: NSDraggingSession,
                             sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            [.copy]
        }
    }
}

// Small helper: add an NSMenuItem backed by a closure.
private extension NSMenu {
    func addItem(withActionTitle title: String, action: @escaping () -> Void) {
        let item = ClosureMenuItem(title: title, action: #selector(ClosureMenuItem.fire), keyEquivalent: "")
        item.onFire = action
        item.target = item
        addItem(item)
    }
}

private final class ClosureMenuItem: NSMenuItem {
    var onFire: (() -> Void)?
    @objc func fire() { onFire?() }
}

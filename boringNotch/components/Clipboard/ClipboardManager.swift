//
//  ClipboardManager.swift
//  boringNotch
//
//  Watches the system pasteboard and keeps a short in-memory history of recent
//  copies (text and images) so they can be re-copied from the notch. History is
//  session-only — nothing is written to disk.
//

import AppKit
import Combine

struct ClipItem: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let text: String?
    let image: NSImage?

    static func == (lhs: ClipItem, rhs: ClipItem) -> Bool { lhs.id == rhs.id }

    var isImage: Bool { image != nil }
}

@MainActor
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published private(set) var items: [ClipItem] = []

    private let maxItems = 25
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var poller: AnyCancellable?

    private init() {
        lastChangeCount = pasteboard.changeCount
    }

    /// Begins polling. Called once when the app sets up the notch.
    func start() {
        guard poller == nil else { return }
        poller = Timer.publish(every: 0.7, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.capture() }
    }

    func clear() { items.removeAll() }

    func remove(_ item: ClipItem) { items.removeAll { $0.id == item.id } }

    /// Copies an existing history item back to the pasteboard.
    func copy(_ item: ClipItem) {
        pasteboard.clearContents()
        if let image = item.image {
            pasteboard.writeObjects([image])
        } else if let text = item.text {
            pasteboard.setString(text, forType: .string)
        }
        // Don't re-capture our own write.
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Capture

    private func capture() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            append(ClipItem(date: Date(), text: text, image: nil), dedupeText: text)
        } else if let image = NSImage(pasteboard: pasteboard) {
            append(ClipItem(date: Date(), text: nil, image: image), dedupeText: nil)
        }
    }

    private func append(_ item: ClipItem, dedupeText: String?) {
        if let dedupeText, let existing = items.firstIndex(where: { $0.text == dedupeText }) {
            items.remove(at: existing)
        }
        items.insert(item, at: 0)
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
    }
}

//
//  ClipboardManager.swift
//  boringNotch
//
//  Watches the system pasteboard and keeps a short history of recent copies
//  (text and images) so they can be re-copied from the notch. History persists
//  to disk (Application Support) so it survives relaunches.
//

import AppKit
import Combine

struct ClipItem: Identifiable, Equatable, Codable {
    var id = UUID()
    let date: Date
    let text: String?
    let imageData: Data?

    static func == (lhs: ClipItem, rhs: ClipItem) -> Bool { lhs.id == rhs.id }

    var image: NSImage? { imageData.flatMap { NSImage(data: $0) } }
    var isImage: Bool { imageData != nil }
}

@MainActor
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published private(set) var items: [ClipItem] = []

    private let maxItems = 25
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var poller: AnyCancellable?

    private let saveURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("boringNotch", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("clipboard.json")
    }()

    private init() {
        lastChangeCount = pasteboard.changeCount
        load()
    }

    /// Begins polling. Called once when the app sets up the notch.
    func start() {
        guard poller == nil else { return }
        poller = Timer.publish(every: 0.7, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.capture() }
    }

    func clear() {
        items.removeAll()
        persist()
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

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
            append(ClipItem(date: Date(), text: text, imageData: nil), dedupeText: text)
        } else if let image = NSImage(pasteboard: pasteboard), let data = Self.pngData(image) {
            append(ClipItem(date: Date(), text: nil, imageData: data), dedupeText: nil)
        }
    }

    private func append(_ item: ClipItem, dedupeText: String?) {
        if let dedupeText, let existing = items.firstIndex(where: { $0.text == dedupeText }) {
            items.remove(at: existing)
        }
        items.insert(item, at: 0)
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data)
        else { return }
        items = decoded
    }

    private func persist() {
        let snapshot = items
        let url = saveURL
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

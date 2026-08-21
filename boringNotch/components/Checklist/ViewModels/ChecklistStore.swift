//
//  ChecklistStore.swift
//  boringNotch
//
//  Owns the in-memory checklist, loads it from current.json, and watches the
//  file for external edits. Mirrors ShelfStateViewModel's singleton/ObservableObject
//  shape.
//

import Foundation
import Defaults

@MainActor
final class ChecklistStore: ObservableObject {
    static let shared = ChecklistStore()

    @Published private(set) var checklist: Checklist = .empty

    /// Ten most recent archived checklists (newest first) for the history picker.
    /// Display-capped only — every archive file is kept on disk.
    @Published private(set) var recentArchives: [ArchivedChecklist] = []

    private let persistence = ChecklistPersistenceService.shared

    // Directory watching (survives atomic writes, which replace the file's inode).
    private var dirSource: DispatchSourceFileSystemObject?
    private var dirDescriptor: CInt = -1

    /// Bytes we last wrote ourselves, used to ignore the change event our own
    /// save triggers.
    private var lastWrittenData: Data?

    // Debounce rapid successive file-system events.
    private var reloadTask: Task<Void, Never>?
    private let reloadDelay: Duration = .milliseconds(150)

    private init() {
        checklist = persistence.load()
        refreshHistory()
        startWatching()
    }

    // MARK: - Derived state

    var isEmpty: Bool { checklist.isEmpty }

    /// First unticked item — what the collapsed notch and collapsed panel show.
    var currentItem: ChecklistItem? { checklist.currentItem }

    // MARK: - Mutation

    /// Toggles an item's done flag and writes the change back to disk.
    func toggle(_ item: ChecklistItem) {
        guard let idx = checklist.items.firstIndex(where: { $0.id == item.id }) else { return }
        checklist.items[idx].done.toggle()
        persist()
    }

    func reload() {
        checklist = persistence.load()
    }

    private func persist() {
        // Record what we wrote so the watcher can distinguish our own save from
        // an external edit.
        lastWrittenData = persistence.save(checklist)
    }

    // MARK: - Firing & history

    /// Makes `newChecklist` the current checklist. The single "fire" path:
    /// archives the existing current.json first (so it's never destroyed), then
    /// writes the new one. Used both for firing and for loading from history.
    func activate(_ newChecklist: Checklist) {
        // Slug comes from the checklist being archived, not the incoming one.
        persistence.archiveCurrentFile(slug: checklist.archiveSlug)
        persistence.pruneArchive(keeping: Defaults[.checklistArchiveRetention])
        checklist = newChecklist
        lastWrittenData = persistence.save(newChecklist)
        refreshHistory()
    }

    /// Archives the current checklist and replaces it with an empty one.
    /// Backs the settings "Clear current checklist" action.
    func clearCurrent() {
        activate(.empty)
    }

    /// Loads an archived checklist as the new current one — same path as firing.
    /// The selected archive file itself is left on disk.
    func loadFromHistory(_ archived: ArchivedChecklist) {
        guard let loaded = persistence.load(from: archived.url) else { return }
        activate(loaded)
    }

    /// Rebuilds `recentArchives` from the archive directory (newest first, top 10).
    func refreshHistory() {
        let defaultName = Defaults[.checklistDefaultName]
        let archives = persistence.archiveURLs().map { url -> ArchivedChecklist in
            let date = ChecklistPersistenceService.modificationDate(url)
            let name = persistence.load(from: url)?.displayName(default: defaultName)
                ?? url.deletingPathExtension().lastPathComponent
            return ArchivedChecklist(url: url, name: name, date: date)
        }
        recentArchives = Array(archives.prefix(max(0, Defaults[.checklistRecentLength])))
    }

    // MARK: - File watching

    private func startWatching() {
        // Watch the containing directory rather than the file itself: an atomic
        // write (temp file + rename) swaps the inode, which would silently orphan
        // a file-level watch.
        let dir = persistence.fileURL.deletingLastPathComponent()
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleReload()
        }
        source.setCancelHandler {
            close(fd)
        }
        dirDescriptor = fd
        dirSource = source
        source.resume()
    }

    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.reloadDelay ?? .milliseconds(150))
            guard let self, !Task.isCancelled else { return }

            let data = try? Data(contentsOf: self.persistence.fileURL)
            // Ignore the event echoing back our own write.
            if let data, data == self.lastWrittenData { return }

            self.lastWrittenData = nil
            self.reload()
            self.refreshHistory()
        }
    }

    deinit {
        dirSource?.cancel()
    }
}

/// A checklist file sitting in the archive directory, surfaced by the history picker.
struct ArchivedChecklist: Identifiable, Equatable, Sendable {
    let url: URL
    let name: String
    let date: Date

    var id: URL { url }
}

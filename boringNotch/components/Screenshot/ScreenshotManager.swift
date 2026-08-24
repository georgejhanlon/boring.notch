//
//  ScreenshotManager.swift
//  boringNotch
//
//  Captures screenshots via the macOS `screencapture` tool (the same engine
//  behind ⌘⇧3 / ⌘⇧4), saves them to ~/Desktop/Screenshots, and auto-names each
//  one from its content using the Anthropic API. History is the set of PNGs in
//  that folder, newest first.
//

import AppKit
import Combine
import SwiftUI

/// One saved screenshot on disk.
struct ScreenshotItem: Identifiable, Equatable {
    let id: URL          // the file URL doubles as a stable identity
    var url: URL
    var name: String
    let date: Date

    static func == (lhs: ScreenshotItem, rhs: ScreenshotItem) -> Bool {
        lhs.url == rhs.url && lhs.name == rhs.name
    }
}

@MainActor
final class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()

    @Published private(set) var items: [ScreenshotItem] = []
    /// Set while a capture is in flight (the picker is up or naming is running).
    @Published private(set) var isBusy = false

    /// ~/Desktop/Screenshots — created on first use.
    private let folder: URL

    /// Where macOS itself saves ⌘⇧3/4 screenshots (default: Desktop).
    private let systemScreenshotDir: URL
    /// The prefix macOS uses for screenshot filenames (default: "Screenshot").
    private let systemScreenshotPrefix: String

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "pdf"]

    // Native-screenshot watcher state.
    private var watcher: DispatchSourceFileSystemObject?
    private var watchedFD: Int32 = -1
    /// Filenames already present/handled in the system folder, so we only pick
    /// up genuinely new captures.
    private var seenSystemFiles: Set<String> = []
    private var rescanTask: Task<Void, Never>?

    private init() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        folder = desktop.appendingPathComponent("Screenshots", isDirectory: true)

        // Resolve the macOS screenshot save location + name prefix.
        systemScreenshotDir = Self.resolveSystemScreenshotDir(fallback: desktop)
        systemScreenshotPrefix = Self.resolveSystemScreenshotPrefix()

        ensureFolder()
        reload()
        startWatchingSystemScreenshots()
    }

    deinit {
        watcher?.cancel()
        if watchedFD >= 0 { close(watchedFD) }
    }

    // MARK: - Capture

    enum Mode {
        case fullScreen   // main display, like ⌘⇧3
        case window       // interactive window pick, like ⌘⇧4 then space
    }

    /// Runs `screencapture`, then renames the file from its AI-generated name.
    func capture(_ mode: Mode) {
        guard !isBusy else { return }
        isBusy = true

        // Capture to a temporary timestamped name first; rename once we have a
        // content-based name (or keep the timestamp if naming fails).
        let stamp = Self.timestampFormatter.string(from: Date())
        let tempURL = folder.appendingPathComponent("Screenshot \(stamp).png")

        var args = ["-x"]                 // -x: no capture sound
        switch mode {
        case .fullScreen: args += ["-m"]  // -m: main display only → one file
        case .window:     args += ["-w", "-o"]  // -w: window mode, -o: no shadow
        }
        args.append(tempURL.path)

        Task.detached { [folder] in
            let ok = Self.runScreencapture(args)
            // A cancelled window pick (Esc) writes no file — nothing to do.
            guard ok, FileManager.default.fileExists(atPath: tempURL.path) else {
                await MainActor.run { self.isBusy = false; self.reload() }
                return
            }

            let finalURL = await Self.rename(tempURL, in: folder)
            await MainActor.run {
                self.isBusy = false
                self.reload()
                _ = finalURL
            }
        }
    }

    // MARK: - History actions

    func reveal(_ item: ScreenshotItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func open(_ item: ScreenshotItem) {
        NSWorkspace.shared.open(item.url)
    }

    func delete(_ item: ScreenshotItem) {
        try? FileManager.default.removeItem(at: item.url)
        reload()
    }

    func openFolder() {
        NSWorkspace.shared.open(folder)
    }

    func thumbnail(for item: ScreenshotItem) -> NSImage? {
        NSImage(contentsOf: item.url)
    }

    // MARK: - Disk

    private func ensureFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func reload() {
        ensureFolder()
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        items = urls
            .filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
            .map { url -> ScreenshotItem in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                let name = url.deletingPathExtension().lastPathComponent
                return ScreenshotItem(id: url, url: url, name: name, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Native screenshot watching (⌘⇧3 / ⌘⇧4)

    /// Watches the macOS screenshot folder and pulls new captures into our
    /// folder, so shots taken with the system shortcut are named and listed too.
    private func startWatchingSystemScreenshots() {
        // If macOS already saves into our folder, our own pipeline handles it.
        guard systemScreenshotDir.standardizedFileURL != folder.standardizedFileURL else { return }

        // Baseline: everything already there is "seen" — only react to new files.
        seenSystemFiles = Set(currentSystemFilenames())

        let fd = Darwin.open(systemScreenshotDir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        watchedFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleSystemScan()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.watchedFD, fd >= 0 { close(fd) }
            self?.watchedFD = -1
        }
        watcher = source
        source.resume()
    }

    /// Debounce bursts of filesystem events and give the file time to finish
    /// writing before we touch it.
    private func scheduleSystemScan() {
        rescanTask?.cancel()
        rescanTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.scanSystemScreenshots()
        }
    }

    private func scanSystemScreenshots() {
        let current = currentSystemFilenames()
        let newNames = Set(current).subtracting(seenSystemFiles)
        seenSystemFiles.formUnion(current)

        for name in newNames where isSystemScreenshot(name) {
            ingestExternal(systemScreenshotDir.appendingPathComponent(name))
        }
    }

    private func currentSystemFilenames() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: systemScreenshotDir.path)) ?? []
    }

    private func isSystemScreenshot(_ name: String) -> Bool {
        let lower = name.lowercased()
        let ext = (name as NSString).pathExtension.lowercased()
        return lower.hasPrefix(systemScreenshotPrefix.lowercased()) && Self.imageExtensions.contains(ext)
    }

    /// Moves an externally-captured screenshot into our folder, then names it.
    private func ingestExternal(_ url: URL) {
        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
        let stamp = Self.timestampFormatter.string(from: Date())
        let temp = folder.appendingPathComponent("Screenshot \(stamp) \(UUID().uuidString.prefix(4)).\(ext)")

        Task.detached { [folder] in
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            do {
                try FileManager.default.moveItem(at: url, to: temp)
            } catch {
                return  // couldn't move (permissions, race) — leave it on the Desktop
            }
            _ = await Self.rename(temp, in: folder)
            await MainActor.run { self.reload() }
        }
    }

    // MARK: - Resolving the macOS screenshot location

    private nonisolated static func resolveSystemScreenshotDir(fallback: URL) -> URL {
        if let raw = CFPreferencesCopyAppValue("location" as CFString, "com.apple.screencapture" as CFString) as? String,
           !raw.isEmpty {
            let expanded = (raw as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: expanded, isDirectory: true)
            }
        }
        return fallback
    }

    private nonisolated static func resolveSystemScreenshotPrefix() -> String {
        if let name = CFPreferencesCopyAppValue("name" as CFString, "com.apple.screencapture" as CFString) as? String,
           !name.isEmpty {
            return name
        }
        return "Screenshot"
    }

    // MARK: - Naming

    /// Asks the API for a content-based name and renames the file. Returns the
    /// final URL (unchanged if naming failed).
    private nonisolated static func rename(_ tempURL: URL, in folder: URL) async -> URL {
        guard let data = try? Data(contentsOf: tempURL) else { return tempURL }
        let apiKey = await MainActor.run { APIKeyStore.shared.apiKey }

        let raw: String
        do {
            raw = try await AnthropicService.shared.nameImage(
                imageBase64: data.base64EncodedString(),
                apiKey: apiKey
            )
        } catch {
            return tempURL  // keep the timestamp name; history still shows it
        }

        let base = sanitize(raw)
        guard !base.isEmpty else { return tempURL }

        let target = uniqueURL(for: base, ext: tempURL.pathExtension, in: folder)
        do {
            try FileManager.default.moveItem(at: tempURL, to: target)
            return target
        } catch {
            return tempURL
        }
    }

    /// Turns a free-text name into a safe filename base (no extension).
    private nonisolated static func sanitize(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -"))
        let cleaned = text
            .components(separatedBy: allowed.inverted)
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(60))
    }

    /// Appends " 2", " 3", … if a file with the base name already exists.
    private nonisolated static func uniqueURL(for base: String, ext: String, in folder: URL) -> URL {
        let suffix = ext.isEmpty ? "png" : ext
        var candidate = folder.appendingPathComponent("\(base).\(suffix)")
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(n).\(suffix)")
            n += 1
        }
        return candidate
    }

    // MARK: - Process

    /// Runs /usr/sbin/screencapture and reports whether it exited cleanly.
    private nonisolated static func runScreencapture(_ args: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return f
    }()
}

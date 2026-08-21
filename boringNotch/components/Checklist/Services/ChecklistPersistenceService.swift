//
//  ChecklistPersistenceService.swift
//  boringNotch
//
//  Resolves and (de)serializes the checklist JSON stored at
//  ~/Library/Application Support/boringNotch/checklists/current.json
//  Mirrors ShelfPersistenceService's conventions.
//

import Foundation

final class ChecklistPersistenceService {
    static let shared = ChecklistPersistenceService()

    /// Location of `current.json`. Exposed so the store can watch it for changes.
    let fileURL: URL

    /// Directory holding archived (fired/replaced) checklists.
    let archiveDirURL: URL

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = (support ?? fm.temporaryDirectory)
            .appendingPathComponent("boringNotch", isDirectory: true)
            .appendingPathComponent("checklists", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("current.json")
        archiveDirURL = dir.appendingPathComponent("archive", isDirectory: true)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    /// Reads and decodes the checklist. Returns an empty checklist if the file is
    /// missing or malformed (mirrors the Shelf service's forgiving load).
    func load() -> Checklist {
        load(from: fileURL) ?? .empty
    }

    /// Decodes a checklist from an arbitrary file (e.g. an archived one).
    /// Returns nil if the file is missing or malformed.
    func load(from url: URL) -> Checklist? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decoder.decode(Checklist.self, from: data)
        } catch {
            print("⚠️ Failed to decode checklist at \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    /// Moves the existing `current.json` into the archive directory, named
    /// `{ISO8601}-{slug}.json` (colons replaced with hyphens so the name is
    /// filesystem-friendly). No-op if there is no current file. Never overwrites
    /// an existing archive file — a counter is appended on collision.
    func archiveCurrentFile(slug: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }

        try? fm.createDirectory(at: archiveDirURL, withIntermediateDirectories: true)

        let timestamp = Self.archiveTimestampFormatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let base = "\(timestamp)-\(slug)"

        var candidate = archiveDirURL.appendingPathComponent("\(base).json")
        var counter = 1
        while fm.fileExists(atPath: candidate.path) {
            candidate = archiveDirURL.appendingPathComponent("\(base)-\(counter).json")
            counter += 1
        }

        do {
            try fm.moveItem(at: fileURL, to: candidate)
        } catch {
            print("Failed to archive checklist: \(error.localizedDescription)")
        }
    }

    private static let archiveTimestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Serializes the checklist to disk atomically. Returns the bytes written so
    /// the store can recognize (and ignore) the file-change event it triggers.
    @discardableResult
    func save(_ checklist: Checklist) -> Data? {
        do {
            let data = try encoder.encode(checklist)
            try data.write(to: fileURL, options: .atomic)
            return data
        } catch {
            print("Failed to save checklist: \(error.localizedDescription)")
            return nil
        }
    }
}

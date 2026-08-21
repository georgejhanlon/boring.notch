//
//  ChecklistItem.swift
//  boringNotch
//
//  A single row in a checklist. Kept intentionally small and Codable so the
//  on-disk `current.json` stays human-editable.
//

import Foundation

struct ChecklistItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var text: String
    var done: Bool

    init(id: UUID = UUID(), text: String, done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }

    enum CodingKeys: String, CodingKey { case id, text, done }

    // Tolerant decoding: `current.json` is authored by hand, so a missing `id`
    // or `done` should not fail the whole file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.text = try container.decode(String.self, forKey: .text)
        self.done = try container.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }
}

struct Checklist: Codable, Equatable, Sendable {
    /// Optional display name for the checklist. Set only from the JSON; nothing
    /// in the UI writes it. Used for the archive slug and the history picker.
    var name: String?
    var title: String
    var items: [ChecklistItem]

    static let empty = Checklist(name: nil, title: "", items: [])

    enum CodingKeys: String, CodingKey { case name, title, items }

    init(name: String? = nil, title: String, items: [ChecklistItem]) {
        self.name = name
        self.title = title
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.items = try container.decodeIfPresent([ChecklistItem].self, forKey: .items) ?? []
    }
}

extension Checklist {
    var isEmpty: Bool { items.isEmpty }

    /// The first item that hasn't been ticked yet — what the collapsed states show.
    var currentItem: ChecklistItem? { items.first { !$0.done } }

    /// Human-facing label, used by the history picker. Falls back through
    /// name → title → first item text → "Untitled".
    var displayName: String {
        if let name, !name.isEmpty { return name }
        if !title.isEmpty { return title }
        if let first = items.first?.text, !first.isEmpty { return first }
        return "Untitled"
    }

    /// Filesystem slug for archive filenames: the name lowercased and hyphenated,
    /// or a slug of the first item's text when name is nil.
    var archiveSlug: String {
        let source = (name?.isEmpty == false ? name! : items.first?.text) ?? "checklist"
        return Self.slugify(source)
    }

    static func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
        let hyphenated = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(hyphenated)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        let slug = String(collapsed.prefix(60))
        return slug.isEmpty ? "checklist" : slug
    }
}

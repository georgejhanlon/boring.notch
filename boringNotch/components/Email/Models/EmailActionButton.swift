//
//  EmailActionButton.swift
//  boringNotch
//
//  The set of triage actions that can occupy a slot in the Email tab's action
//  row. Mirrors MusicControlButton so the Email settings can offer the same
//  drag-to-arrange configuration the music player uses.
//

import Defaults
import SwiftUI

enum EmailActionButton: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case archive
    case delete
    case reply
    case replyAll
    case forward
    case openInMail
    case none

    var id: String { rawValue }

    static let defaultLayout: [EmailActionButton] = [
        .archive,
        .delete,
        .reply,
        .forward
    ]

    static let slotCount: Int = 4

    static let pickerOptions: [EmailActionButton] = [
        .archive,
        .delete,
        .reply,
        .replyAll,
        .forward,
        .openInMail
    ]

    var label: String {
        switch self {
        case .archive: return "Archive"
        case .delete: return "Delete"
        case .reply: return "Reply"
        case .replyAll: return "Reply All"
        case .forward: return "Forward"
        case .openInMail: return "Open in Mail"
        case .none: return "Empty slot"
        }
    }

    var iconName: String {
        switch self {
        case .archive: return "archivebox.fill"
        case .delete: return "trash.fill"
        case .reply: return "arrowshape.turn.up.left.fill"
        case .replyAll: return "arrowshape.turn.up.left.2.fill"
        case .forward: return "arrowshape.turn.up.right.fill"
        case .openInMail: return "envelope.open.fill"
        case .none: return ""
        }
    }

    var tint: Color {
        switch self {
        case .archive: return .blue
        case .delete: return .red
        case .reply: return .accentColor
        case .replyAll: return .accentColor.opacity(0.75)
        case .forward: return .gray
        case .openInMail: return .indigo
        case .none: return .clear
        }
    }
}

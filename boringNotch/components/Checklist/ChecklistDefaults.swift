//
//  ChecklistDefaults.swift
//  boringNotch
//
//  Defaults keys for the Checklist feature. Kept in a feature-local
//  `extension Defaults.Keys` (Swift allows multiple such blocks) so the shared
//  Constants.swift stays untouched.
//

import Foundation
import Defaults

/// Drives the completion "swoosh" speed (item 5).
enum ChecklistAnimationSpeed: String, CaseIterable, Identifiable, Defaults.Serializable {
    case slow
    case normal
    case fast

    var id: String { rawValue }

    var localizedString: String {
        switch self {
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }

    /// Response for the removal spring — lower is snappier.
    var response: Double {
        switch self {
        case .slow: return 0.5
        case .normal: return 0.32
        case .fast: return 0.18
        }
    }
}

extension Defaults.Keys {
    /// Always-on mode: show a compact checklist strip inside the closed notch.
    static let checklistAlwaysOn = Key<Bool>("checklistAlwaysOn", default: false)
    /// How many upcoming items appear in the always-on strip.
    static let checklistAlwaysOnCount = Key<Int>("checklistAlwaysOnCount", default: 4)
    /// Whether the "completed" section is shown in the expanded panel.
    static let checklistShowCompleted = Key<Bool>("checklistShowCompleted", default: true)
    /// Number of archived checklists to keep on disk. 0 = unlimited.
    static let checklistArchiveRetention = Key<Int>("checklistArchiveRetention", default: 50)
    /// How many archives appear in the "recent" disclosure.
    static let checklistRecentLength = Key<Int>("checklistRecentLength", default: 10)
    /// Completion animation speed.
    static let checklistAnimationSpeed = Key<ChecklistAnimationSpeed>("checklistAnimationSpeed", default: .normal)
    /// Default checklist name when the JSON does not supply one.
    static let checklistDefaultName = Key<String>("checklistDefaultName", default: "Today")
}

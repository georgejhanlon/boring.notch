//
//  MailMessage.swift
//  boringNotch
//
//  A lightweight snapshot of an Apple Mail inbox message used by the triage tab.
//  Identity is Mail's numeric message id, which the service uses to address the
//  message for content fetches and actions.
//

import Foundation

struct MailMessage: Identifiable, Equatable, Sendable {
    let id: String          // Mail's numeric message id, as a string
    let sender: String      // raw "Name <addr>" as Mail reports it
    let subject: String
    let dateString: String

    /// Display name only, e.g. "Jane Appleseed" from "Jane Appleseed <jane@x.com>".
    var senderName: String {
        if let lt = sender.firstIndex(of: "<") {
            let name = sender[..<lt].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name }
        }
        return sender.trimmingCharacters(in: .whitespaces)
    }
}

//
//  MailService.swift
//  boringNotch
//
//  Talks to Apple Mail over AppleScript (NSAppleScript, sandbox-permitted via the
//  com.apple.mail temporary apple-events exception). All calls run off the main
//  thread and surface Mail's own error text on failure.
//

import AppKit
import Foundation

enum MailError: LocalizedError {
    case script(String)

    var errorDescription: String? {
        switch self {
        case .script(let message): return message
        }
    }
}

final class MailService {
    static let shared = MailService()

    // Field/record separators unlikely to appear in mail metadata.
    private static let fs = "\u{1F}"
    private static let rs = "\u{1E}"

    private let queue = DispatchQueue(label: "com.notchpro.app.mailservice", qos: .userInitiated)

    private init() {}

    // MARK: - Script runner

    @discardableResult
    private func run(_ source: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                var errorInfo: NSDictionary?
                let script = NSAppleScript(source: source)
                let descriptor = script?.executeAndReturnError(&errorInfo)
                if let errorInfo {
                    let message = (errorInfo[NSAppleScript.errorMessage] as? String)
                        ?? "AppleScript error \(errorInfo[NSAppleScript.errorNumber] ?? "")"
                    continuation.resume(throwing: MailError.script(message))
                } else {
                    continuation.resume(returning: descriptor?.stringValue ?? "")
                }
            }
        }
    }

    /// Locates a message by id inside the AppleScript body being built.
    private func locate(_ id: String) -> String {
        "set theMessage to (first message of inbox whose id is \(id))"
    }

    // MARK: - Reads

    func fetchInbox(limit: Int) async throws -> [MailMessage] {
        let source = """
        tell application "Mail"
            set output to ""
            set inboxMessages to messages of inbox
            set total to (count of inboxMessages)
            set lim to \(limit)
            if total < lim then set lim to total
            repeat with i from 1 to lim
                set m to item i of inboxMessages
                set output to output & ((id of m) as string) & "\(Self.fs)" & (sender of m) & "\(Self.fs)" & (subject of m) & "\(Self.fs)" & ((date received of m) as string) & "\(Self.rs)"
            end repeat
            return output
        end tell
        """
        let raw = try await run(source)
        return raw
            .components(separatedBy: Self.rs)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .compactMap { record in
                let fields = record.components(separatedBy: Self.fs)
                guard fields.count >= 4 else { return nil }
                return MailMessage(id: fields[0], sender: fields[1], subject: fields[2], dateString: fields[3])
            }
    }

    func content(for id: String) async throws -> String {
        let source = """
        tell application "Mail"
            \(locate(id))
            return content of theMessage
        end tell
        """
        return try await run(source)
    }

    // MARK: - Actions

    func delete(id: String) async throws {
        let source = """
        tell application "Mail"
            \(locate(id))
            delete theMessage
        end tell
        """
        try await run(source)
    }

    /// Best-effort archive: move the message to an "Archive" mailbox on its own
    /// account. Throws (surfaced to the UI) if the account has no such mailbox.
    func archive(id: String) async throws {
        let source = """
        tell application "Mail"
            \(locate(id))
            set theAccount to account of (mailbox of theMessage)
            set archiveBox to (first mailbox of theAccount whose name is "Archive")
            set mailbox of theMessage to archiveBox
        end tell
        """
        try await run(source)
    }

    func reply(id: String, all: Bool) async throws {
        let source = """
        tell application "Mail"
            \(locate(id))
            reply theMessage opening window yes reply to all \(all ? "yes" : "no")
            activate
        end tell
        """
        try await run(source)
    }

    func forward(id: String) async throws {
        let source = """
        tell application "Mail"
            \(locate(id))
            forward theMessage opening window yes
            activate
        end tell
        """
        try await run(source)
    }

    /// Opens the message in Mail and brings the app forward.
    func openInMail(id: String) async throws {
        let source = """
        tell application "Mail"
            activate
            \(locate(id))
            open theMessage
        end tell
        """
        try await run(source)
    }
}

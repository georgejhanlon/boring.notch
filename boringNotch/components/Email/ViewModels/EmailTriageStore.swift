//
//  EmailTriageStore.swift
//  boringNotch
//
//  Holds the fetched inbox snapshot, the cursor into it, and the body of the
//  message currently under review. Archive/delete remove the message from the
//  snapshot and advance; reply/forward hand off to Mail and leave it in place.
//

import Foundation

@MainActor
final class EmailTriageStore: ObservableObject {
    static let shared = EmailTriageStore()

    @Published private(set) var messages: [MailMessage] = []
    @Published private(set) var index: Int = 0
    @Published private(set) var body: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isBusy = false
    @Published var errorText: String?

    private let fetchLimit = 30
    private var bodyToken = 0

    private init() {}

    // MARK: - Derived

    var current: MailMessage? { messages.indices.contains(index) ? messages[index] : nil }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < messages.count - 1 }
    var isEmpty: Bool { messages.isEmpty }

    // MARK: - Loading

    func loadInboxIfNeeded() async {
        guard messages.isEmpty, !isLoading else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let fetched = try await MailService.shared.fetchInbox(limit: fetchLimit)
            messages = fetched
            index = 0
            await loadBody()
        } catch {
            messages = []
            body = ""
            errorText = error.localizedDescription
        }
    }

    private func loadBody() async {
        guard let id = current?.id else { body = ""; return }
        bodyToken += 1
        let token = bodyToken
        do {
            let text = try await MailService.shared.content(for: id)
            // Ignore if the cursor moved while we were fetching.
            guard token == bodyToken else { return }
            body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            guard token == bodyToken else { return }
            body = ""
        }
    }

    // MARK: - Navigation

    func goBack() {
        guard canGoBack else { return }
        index -= 1
        Task { await loadBody() }
    }

    func goForward() {
        guard canGoForward else { return }
        index += 1
        Task { await loadBody() }
    }

    // MARK: - Actions

    private func removeCurrentAndAdvance() {
        guard messages.indices.contains(index) else { return }
        messages.remove(at: index)
        if index > messages.count - 1 { index = max(0, messages.count - 1) }
    }

    /// Archive/delete advance the UI immediately and run the Mail operation in the
    /// background, so triaging feels instant. On failure we re-fetch the inbox so
    /// the list reflects Mail's real state again.
    func archive() {
        guard let id = current?.id else { return }
        removeCurrentAndAdvance()
        Task { await loadBody() }
        runInBackground { try await MailService.shared.archive(id: id) }
    }

    func delete() {
        guard let id = current?.id else { return }
        removeCurrentAndAdvance()
        Task { await loadBody() }
        runInBackground { try await MailService.shared.delete(id: id) }
    }

    /// Hand-offs to Mail leave the message in place; fire and forget so the button
    /// responds without waiting on Mail to open its composer.
    func reply(all: Bool) {
        guard let id = current?.id else { return }
        runInBackground { try await MailService.shared.reply(id: id, all: all) }
    }

    func forward() {
        guard let id = current?.id else { return }
        runInBackground { try await MailService.shared.forward(id: id) }
    }

    func openInMail() {
        guard let id = current?.id else { return }
        runInBackground { try await MailService.shared.openInMail(id: id) }
    }

    private func runInBackground(_ work: @escaping () async throws -> Void) {
        errorText = nil
        Task {
            do {
                try await work()
            } catch {
                errorText = error.localizedDescription
                await reload()
            }
        }
    }
}

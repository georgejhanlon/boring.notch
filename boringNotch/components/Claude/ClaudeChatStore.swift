//
//  ClaudeChatStore.swift
//  boringNotch
//
//  Holds the in-notch Claude conversation and drives streaming replies from the
//  Anthropic API. One shared store so the chat survives closing/reopening the
//  notch within a session.
//

import Foundation

@MainActor
final class ClaudeChatStore: ObservableObject {
    static let shared = ClaudeChatStore()

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isStreaming = false
    @Published var errorText: String?

    private init() {}

    var isEmpty: Bool { messages.isEmpty }

    func clear() {
        messages.removeAll()
        errorText = nil
    }

    /// Starts a fresh conversation seeded with some context (e.g. from Summarise).
    func startChat(with context: String) {
        clear()
        send(context)
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        errorText = nil
        messages.append(ChatMessage(role: .user, text: trimmed))

        // Append an empty assistant turn we stream into.
        let replyIndex = messages.count
        messages.append(ChatMessage(role: .assistant, text: ""))
        isStreaming = true

        let history = Array(messages[..<replyIndex])
        let apiKey = APIKeyStore.shared.apiKey

        Task {
            do {
                try await AnthropicService.shared.stream(history: history, apiKey: apiKey) { [weak self] delta in
                    guard let self, self.messages.indices.contains(replyIndex) else { return }
                    self.messages[replyIndex].text += delta
                }
            } catch {
                errorText = error.localizedDescription
                // Drop the empty assistant bubble if nothing streamed in.
                if messages.indices.contains(replyIndex), messages[replyIndex].text.isEmpty {
                    messages.remove(at: replyIndex)
                }
            }
            isStreaming = false
        }
    }
}

//
//  AnthropicService.swift
//  boringNotch
//
//  Minimal native client for the Anthropic Messages API, used by the in-notch
//  Claude chat. Streams the response over SSE so replies render token-by-token.
//  No SDK dependency — just URLSession against api.anthropic.com.
//

import Foundation

enum AnthropicError: LocalizedError {
    case missingKey
    case http(Int, String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add your Anthropic API key in Settings › Claude to start chatting."
        case .http(let code, let message):
            return "Claude API error (\(code)): \(message)"
        case .transport(let message):
            return message
        }
    }
}

/// A single chat turn sent to / shown in the UI.
struct ChatMessage: Identifiable, Equatable {
    enum Role: String { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

struct AnthropicService {
    static let shared = AnthropicService()

    private let model = "claude-opus-4-8"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let systemPrompt =
        "You are a quick assistant embedded in a small macOS notch widget. "
        + "Answer directly and concisely — a few sentences at most unless the user asks for more. "
        + "Respond only with your final answer; don't narrate your reasoning."

    /// Streams the assistant reply for the given history. `onDelta` is called on
    /// the main actor for each chunk of text as it arrives.
    func stream(
        history: [ChatMessage],
        apiKey: String,
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw AnthropicError.missingKey }

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "stream": true,
            "system": systemPrompt,
            "messages": history.map { ["role": $0.role.rawValue, "content": $0.text] },
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            throw AnthropicError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.transport("No response from Claude.")
        }

        // On an error status the body is JSON, not SSE — read it for the message.
        guard (200..<300).contains(http.statusCode) else {
            var body = ""
            for try await line in bytes.lines { body += line }
            throw AnthropicError.http(http.statusCode, Self.extractErrorMessage(body))
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard !json.isEmpty, json != "[DONE]",
                  let data = json.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            let type = obj["type"] as? String
            if type == "content_block_delta",
               let delta = obj["delta"] as? [String: Any],
               delta["type"] as? String == "text_delta",
               let text = delta["text"] as? String {
                await onDelta(text)
            } else if type == "error", let err = obj["error"] as? [String: Any] {
                throw AnthropicError.http(http.statusCode, (err["message"] as? String) ?? "stream error")
            }
        }
    }

    private static func extractErrorMessage(_ body: String) -> String {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any],
              let message = err["message"] as? String
        else { return body.isEmpty ? "Unknown error" : body }
        return message
    }
}

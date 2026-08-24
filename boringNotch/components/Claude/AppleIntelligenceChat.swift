//
//  AppleIntelligenceChat.swift
//  boringNotch
//
//  On-device chat backend for the notch chat, using Apple Intelligence's
//  Foundation Models. Free and private — no network, no API key. The session is
//  kept so the conversation retains context across turns; `reset()` starts fresh.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

final class AppleIntelligenceChat {
    /// Whether the on-device model is usable on this Mac right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Holds the LanguageModelSession on macOS 26 (typed as AnyObject so the
    /// property is valid on older deployment targets).
    private var sessionBox: AnyObject?

    func reset() { sessionBox = nil }

    /// Returns the full reply; the session retains prior turns for context.
    func respond(to prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let session: LanguageModelSession
            if let existing = sessionBox as? LanguageModelSession {
                session = existing
            } else {
                session = LanguageModelSession {
                    "You are a concise, helpful assistant embedded in a small macOS notch widget. Answer directly and briefly — a few sentences unless the user asks for more."
                }
                sessionBox = session
            }
            let response = try await session.respond { prompt }
            return response.content
        }
        #endif
        throw NSError(
            domain: "AppleIntelligence", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence isn't available on this Mac. Enable it in System Settings, or switch back to Claude."]
        )
    }
}

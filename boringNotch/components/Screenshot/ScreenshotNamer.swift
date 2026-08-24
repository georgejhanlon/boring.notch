//
//  ScreenshotNamer.swift
//  boringNotch
//
//  The seam for turning a screenshot's pixels into a short name. Swapping the
//  backend (e.g. to on-device Apple Intelligence) is a one-line change in
//  ScreenshotManager: assign a different `ScreenshotNamer`.
//

import Foundation

/// Produces a short, human name for an image. Returns nil if unavailable or the
/// attempt failed — the caller then keeps the file's provisional timestamp name.
protocol ScreenshotNamer: Sendable {
    func name(imageData: Data) async -> String?
}

/// Names screenshots with the Anthropic API (vision). Costs API tokens.
struct AnthropicScreenshotNamer: ScreenshotNamer {
    func name(imageData: Data) async -> String? {
        let apiKey = await MainActor.run { APIKeyStore.shared.apiKey }
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return try? await AnthropicService.shared.nameImage(
            imageBase64: imageData.base64EncodedString(),
            apiKey: apiKey
        )
    }
}

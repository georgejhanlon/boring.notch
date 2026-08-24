//
//  AppleIntelligenceNamer.swift
//  boringNotch
//
//  On-device screenshot naming — no API cost, fully private. Vision extracts
//  visible text (OCR) and subject tags; Apple Intelligence's on-device model
//  turns that into a short name. If the model isn't available, a local
//  heuristic derives a name from the same signals. Never calls the network.
//

import Foundation
import Vision

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleIntelligenceNamer: ScreenshotNamer {
    func name(imageData: Data) async -> String? {
        let context = Self.extractContext(from: imageData)

        // Prefer the on-device model when Apple Intelligence is available.
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability,
               let modelName = await Self.modelName(text: context.text, tags: context.tags) {
                return modelName
            }
        }
        #endif

        // Local fallback — good enough, and free.
        return Self.heuristicName(text: context.text, tags: context.tags)
    }

    // MARK: - On-device model

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func modelName(text: String, tags: [String]) async -> String? {
        let instructions = """
        You name screenshots. Reply with ONLY a short filename — 3 to 6 words \
        describing the screenshot's main content. Use only letters, numbers, \
        spaces and hyphens. No file extension, no quotes, no other punctuation.
        """
        let prompt = """
        Visible text: \(text.isEmpty ? "(none)" : text)
        Detected subjects: \(tags.isEmpty ? "(none)" : tags.joined(separator: ", "))
        Name this screenshot.
        """
        do {
            let session = LanguageModelSession { instructions }
            let response = try await session.respond { prompt }
            let name = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        } catch {
            return nil
        }
    }
    #endif

    // MARK: - Vision extraction

    private static func extractContext(from data: Data) -> (text: String, tags: [String]) {
        let handler = VNImageRequestHandler(data: data, options: [:])

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .fast
        textRequest.usesLanguageCorrection = false

        let classifyRequest = VNClassifyImageRequest()

        try? handler.perform([textRequest, classifyRequest])

        let lines = (textRequest.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
        let text = lines.prefix(30).joined(separator: " ")

        let tags = (classifyRequest.results ?? [])
            .filter { $0.confidence > 0.3 }
            .prefix(5)
            .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }

        return (text, Array(tags))
    }

    // MARK: - Local fallback

    private static func heuristicName(text: String, tags: [String]) -> String? {
        if !tags.isEmpty {
            return tags.prefix(2).joined(separator: " ")
        }
        let words = text.split(whereSeparator: { $0.isWhitespace }).prefix(6)
        if !words.isEmpty {
            return words.joined(separator: " ")
        }
        return nil  // nothing to go on — keep the timestamp name
    }
}

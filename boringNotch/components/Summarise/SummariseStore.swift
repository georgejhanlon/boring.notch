//
//  SummariseStore.swift
//  boringNotch
//
//  Drives the Summarise feature: grab the current selection (or clipboard),
//  send it to Claude, and stream back a short summary shown in the notch.
//

import AppKit

@MainActor
final class SummariseStore: ObservableObject {
    static let shared = SummariseStore()

    enum State: Equatable {
        case capturing
        case summarising
        case done
        case error(String)
    }

    @Published private(set) var state: State = .capturing
    @Published private(set) var summary: String = ""
    /// The captured source text (for "chat in more detail"). Empty for images.
    @Published private(set) var sourceText: String = ""

    private init() {}

    /// Copies the current selection to the clipboard, reads it, and summarises.
    func capture() {
        state = .capturing
        summary = ""
        sourceText = ""

        Self.synthesizeCopy()

        // Give the frontmost app a beat to place the selection on the pasteboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.readAndSummarise()
        }
    }

    private func readAndSummarise() {
        let pb = NSPasteboard.general
        let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = NSImage(pasteboard: pb)
        let imageBase64 = image.flatMap(Self.pngBase64)

        guard (text?.isEmpty == false) || imageBase64 != nil else {
            state = .error("Nothing to summarise. Select some text or copy an image, then try again.")
            return
        }
        sourceText = text ?? ""
        state = .summarising

        Task {
            do {
                try await AnthropicService.shared.streamSummary(
                    text: text,
                    imageBase64: imageBase64,
                    apiKey: APIKeyStore.shared.apiKey
                ) { [weak self] delta in
                    self?.summary += delta
                }
                state = .done
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

    /// Posts ⌘C to the frontmost app so its selection lands on the pasteboard.
    /// Requires Accessibility permission; a no-op without it.
    private static func synthesizeCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 0x08 // "C"
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private static func pngBase64(_ image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return nil }
        return png.base64EncodedString()
    }
}

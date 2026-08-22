//
//  ClaudeChatView.swift
//  boringNotch
//
//  A native, custom chat interface for Claude that lives inside the notch. Talks
//  to the Anthropic Messages API (key configured in Settings › Claude) and
//  renders a compact bubble conversation with an input field. While the tab is
//  open the notch is held open and made key so typing works.
//

import Defaults
import SwiftUI

extension Color {
    /// Claude's brand coral/orange, used for the active tab tint and user bubbles.
    static let claudeOrange = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
}

struct ClaudeChatView: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @StateObject private var store = ClaudeChatStore.shared
    @Default(.anthropicAPIKey) private var apiKey

    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            header
            if apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
                setupPrompt
            } else {
                conversation
                inputBar
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Keep the notch open and key so the field can receive typing.
        .background(NotchKeyFocusEnabler(isEditing: true))
        .onAppear {
            SharingStateManager.shared.beginInteraction()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { inputFocused = true }
        }
        .onDisappear { SharingStateManager.shared.endInteraction() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            ClaudeMark(size: 15, color: .claudeOrange)
            Text("Claude")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            if store.isStreaming {
                ProgressView().controlSize(.small).progressViewStyle(.circular)
            }
            Spacer()
            Button {
                store.clear()
                inputFocused = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .imageScale(.small).foregroundStyle(.gray).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New chat")
            .disabled(store.isEmpty)

            Button {
                withAnimation(.smooth) { coordinator.currentView = .home }
            } label: {
                Image(systemName: "xmark")
                    .imageScale(.small).foregroundStyle(.gray).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close Claude")
        }
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if store.isEmpty {
                        emptyState
                    }
                    ForEach(store.messages) { message in
                        bubble(message).id(message.id)
                    }
                    if let error = store.errorText {
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 2)
            }
            .onChange(of: store.messages.last?.text) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: store.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Text("Ask Claude anything")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text("Quick questions, right from the notch.")
                .font(.system(size: 10))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 10)
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser { Spacer(minLength: 24) }
            Text(message.text.isEmpty ? "…" : message.text)
                .font(.system(size: 11))
                .foregroundStyle(isUser ? .white : Color(white: 0.92))
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isUser ? Color.claudeOrange.opacity(0.85) : Color.white.opacity(0.10))
                )
            if !isUser { Spacer(minLength: 24) }
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message Claude…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .lineLimit(1...3)
                .focused($inputFocused)
                .onSubmit(send)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(canSend ? Color.claudeOrange : Color.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isStreaming
    }

    private func send() {
        guard canSend else { return }
        store.send(draft)
        draft = ""
        inputFocused = true
    }

    // MARK: - Setup (no API key yet)

    private var setupPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.horizontal.fill")
                .foregroundStyle(.gray)
                .imageScale(.large)
            Text("Add your Anthropic API key")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text("Settings › Claude, then paste your key to start chatting.")
                .font(.system(size: 10))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                DispatchQueue.main.async { SettingsWindowController.shared.showWindow() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.claudeOrange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Claude logo mark

/// A lightweight approximation of the Claude "sunburst" mark drawn as radiating
/// spokes, so we don't need to ship the official asset.
struct ClaudeMark: View {
    var size: CGFloat
    var color: Color

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2
            let spokes = 11
            for i in 0..<spokes {
                let angle = (Double(i) / Double(spokes)) * 2 * .pi
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radius,
                    y: center.y + CGFloat(sin(angle)) * radius
                ))
                context.stroke(path, with: .color(color), lineWidth: size * 0.13)
            }
        }
        .frame(width: size, height: size)
    }
}

/// While the Claude tab is open we flip the notch window to key so its text
/// field can receive typing, restoring the default when the tab closes.
private struct NotchKeyFocusEnabler: NSViewRepresentable {
    var isEditing: Bool

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window as? BoringNotchSkyLightWindow else { return }
            if isEditing {
                if !window.isKeyEnabled {
                    window.isKeyEnabled = true
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeKey()
                }
            } else if window.isKeyEnabled {
                window.isKeyEnabled = false
                window.resignKey()
            }
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        if let window = nsView.window as? BoringNotchSkyLightWindow, window.isKeyEnabled {
            window.isKeyEnabled = false
            window.resignKey()
        }
    }
}

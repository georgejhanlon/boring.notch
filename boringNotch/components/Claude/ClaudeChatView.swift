//
//  ClaudeChatView.swift
//  boringNotch
//
//  A native, custom chat interface for Claude that lives inside the notch. Talks
//  to the Anthropic Messages API (key configured in Settings › Claude) and
//  renders a compact bubble conversation with an input field. While the tab is
//  open the notch is held open and made key so typing works.
//

import SwiftUI

extension Color {
    /// Claude's brand coral/orange, used for the active tab tint and user bubbles.
    static let claudeOrange = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
}

struct ClaudeChatView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @StateObject private var store = ClaudeChatStore.shared
    @StateObject private var keyStore = APIKeyStore.shared

    @State private var draft: String = ""
    @State private var showSwitchConfirm = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            header
            if store.backend == .claude && !keyStore.hasKey {
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
        .overlay {
            if showSwitchConfirm { switchConfirm }
        }
        // Keep the notch open and key so the field can receive typing.
        .background(NotchKeyFocusEnabler(isEditing: true))
        .onAppear {
            SharingStateManager.shared.beginInteraction()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { inputFocused = true }
        }
        .onDisappear { SharingStateManager.shared.endInteraction() }
        // Click-off: when the user clicks another app, the notch loses focus —
        // close it instead of waiting for a hover-out.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            closeOnClickOff()
        }
    }

    private func closeOnClickOff() {
        guard coordinator.currentView == .claude, vm.notchState == .open else { return }
        SharingStateManager.shared.endInteraction()
        coordinator.currentView = .home
        vm.close()
    }

    /// Hands the conversation off to the Claude desktop app. There's no public
    /// deep link to create a pre-filled chat, so we copy the transcript, open a
    /// new chat in the app, then best-effort paste it into the input (Cmd+V) —
    /// leaving it for the user to send. If auto-paste can't fire (accessibility
    /// permission), the transcript is still on the clipboard to paste manually.
    private func exportToClaudeDesktop() {
        guard !store.isEmpty else { return }

        let header = "Continuing a conversation started in the notch:\n"
        let transcript = header + store.messages
            .map { ($0.role == .user ? "Me: " : "Claude: ") + $0.text }
            .joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)

        let workspace = NSWorkspace.shared
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        if let appURL = workspace.urlForApplication(withBundleIdentifier: "com.anthropic.claudefordesktop") {
            workspace.openApplication(at: appURL, configuration: config) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { Self.pasteIntoFrontmostApp() }
            }
        } else if let url = URL(string: "https://claude.ai/new") {
            workspace.open(url)
        }
    }

    /// Synthesizes a ⌘V into whichever app is frontmost (the Claude app after we
    /// activate it). Requires Accessibility permission; a no-op without it.
    private static func pasteIntoFrontmostApp() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09 // "V"
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            // One-click switch between Claude and on-device Apple Intelligence.
            // Confirm first if there's a chat in progress (switching starts anew).
            Button {
                if store.isEmpty {
                    performBackendSwitch()
                } else {
                    withAnimation(.smooth) { showSwitchConfirm = true }
                }
            } label: {
                HStack(spacing: 5) {
                    backendIcon
                    Text(store.backend.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.gray)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Switch chat model (Claude ⇄ Apple Intelligence)")

            Button {
                // Summarise whatever's on the clipboard (the notch is key while
                // this tab is open, so we can't grab a fresh selection here).
                SummariseStore.shared.capture(copyFirst: false)
                withAnimation(.smooth) { coordinator.currentView = .summarise }
            } label: {
                Image(systemName: "sparkles")
                    .imageScale(.small).foregroundStyle(.gray).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Summarise the clipboard")

            Button(action: exportToClaudeDesktop) {
                Image(systemName: "arrow.up.forward.app")
                    .imageScale(.small).foregroundStyle(.gray).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open this chat in the Claude desktop app")
            .disabled(store.isEmpty)

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

    /// The model we'd switch to from the current one.
    private var otherBackend: ChatBackend {
        store.backend == .claude ? .appleIntelligence : .claude
    }

    /// Accent per backend: Claude orange, or iMessage blue for Apple Intelligence.
    private func accent(for backend: ChatBackend) -> Color {
        backend == .appleIntelligence
            ? Color(red: 0.0, green: 0.478, blue: 1.0)
            : .claudeOrange
    }

    /// User bubble / send accent for the current backend.
    private var userAccent: Color { accent(for: store.backend) }

    private func performBackendSwitch() {
        let next = otherBackend
        withAnimation(.smooth) {
            store.clear()          // switching starts a fresh chat
            store.backend = next
            showSwitchConfirm = false
        }
        inputFocused = true
    }

    // MARK: - Switch confirmation (in-notch, not an NSAlert)

    private var switchConfirm: some View {
        ZStack {
            Color.black.opacity(0.45)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.smooth) { showSwitchConfirm = false } }

            VStack(spacing: 8) {
                Text("Switch to \(otherBackend.title)?")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text("This will start a new chat.")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.smooth) { showSwitchConfirm = false }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        performBackendSwitch()
                    } label: {
                        Text("Switch")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Capsule().fill(accent(for: otherBackend)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.13))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12))
            )
            .fixedSize()
        }
    }

    @ViewBuilder private var backendIcon: some View {
        switch store.backend {
        case .claude:
            ClaudeMark(size: 14, color: .claudeOrange)
        case .appleIntelligence:
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.42, blue: 0.55),
                            Color(red: 0.66, green: 0.36, blue: 0.93),
                            Color(red: 0.29, green: 0.56, blue: 0.99),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
        Text("Ask \(store.backend.title) anything")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
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
                        .fill(isUser ? userAccent.opacity(0.85) : Color.white.opacity(0.10))
                )
            if !isUser { Spacer(minLength: 24) }
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message \(store.backend.title)…", text: $draft, axis: .vertical)
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
                    .foregroundStyle(canSend ? userAccent : Color.gray.opacity(0.5))
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

/// The Claude "sunburst" logo, tinted so it can render grey (idle) or Claude
/// orange (active). Backed by the `claude-ai` template asset.
struct ClaudeMark: View {
    var size: CGFloat
    var color: Color

    var body: some View {
        Image("claude-ai")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(color)
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

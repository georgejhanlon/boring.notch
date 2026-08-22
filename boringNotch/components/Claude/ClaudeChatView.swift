//
//  ClaudeChatView.swift
//  boringNotch
//
//  A "light" Claude chat embedded in the notch. It loads claude.ai in a
//  WKWebView using a persistent session, so it signs in with the user's normal
//  Claude login (no API key) and stays logged in between launches. Selecting the
//  Claude tab expands the notch into a taller panel to give the chat room.
//

import SwiftUI
import WebKit

extension Color {
    /// Claude's brand coral/orange, used for the active tab tint.
    static let claudeOrange = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
}

struct ClaudeChatView: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            ClaudeWebView()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 10)
        .frame(width: claudeNotchSize.width)
        // Grow the hosting window to fit the taller chat, and restore it when the
        // view goes away (switching tab / closing the notch).
        .background(NotchWindowHeightResizer(height: claudeWindowSize.height))
    }

    private var header: some View {
        HStack(spacing: 8) {
            ClaudeMark(size: 15, color: .claudeOrange)
            Text("Claude")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                NotificationCenter.default.post(name: .claudeReload, object: nil)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.small)
                    .foregroundStyle(.gray)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reload chat")

            Button {
                withAnimation(.smooth) { coordinator.currentView = .home }
            } label: {
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .foregroundStyle(.gray)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close Claude")
        }
        .padding(.bottom, 6)
    }
}

extension Notification.Name {
    static let claudeReload = Notification.Name("claudeReload")
}

// MARK: - Claude logo mark

/// A lightweight approximation of the Claude "sunburst" mark drawn as radiating
/// spokes, so we don't need to ship the official asset. Swap for the real logo
/// image if/when it's added to the asset catalog.
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

// MARK: - Embedded claude.ai web view

struct ClaudeWebView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Persistent data store keeps the login/cookies between launches.
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = true

        if webView.url == nil {
            webView.load(URLRequest(url: Coordinator.homeURL))
        }

        context.coordinator.observe(webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        static let homeURL = URL(string: "https://claude.ai/new")!

        private var reloadObserver: NSObjectProtocol?

        func observe(_ webView: WKWebView) {
            reloadObserver = NotificationCenter.default.addObserver(
                forName: .claudeReload, object: nil, queue: .main
            ) { [weak webView] _ in
                webView?.reload()
            }
        }

        deinit {
            if let reloadObserver { NotificationCenter.default.removeObserver(reloadObserver) }
        }

        // Load target=_blank / OAuth popups (e.g. Google sign-in) in the same view.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

// MARK: - Window height resizer

/// Resizes the hosting notch window to `height` while this view is on screen and
/// restores it to `windowSize.height` when it disappears, keeping the window's
/// top edge anchored to the screen.
struct NotchWindowHeightResizer: NSViewRepresentable {
    let height: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { Self.setHeight(height, for: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { Self.setHeight(height, for: nsView.window) }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        let window = nsView.window
        DispatchQueue.main.async { setHeight(windowSize.height, for: window) }
    }

    private static func setHeight(_ height: CGFloat, for window: NSWindow?) {
        guard let window, abs(window.frame.height - height) > 0.5 else { return }
        var frame = window.frame
        let top = frame.maxY
        frame.size.height = height
        frame.origin.y = top - height
        window.setFrame(frame, display: true, animate: true)
    }
}

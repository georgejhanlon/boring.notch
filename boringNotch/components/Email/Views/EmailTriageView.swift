//
//  EmailTriageView.swift
//  boringNotch
//
//  The Email triage tab. Steps through the Apple Mail inbox with back/forward
//  arrows, shows the current message Mail-style (bold sender / subject / grey
//  preview, left aligned) on a light card, and offers round Archive / Delete /
//  Reply / Forward actions. Hovering Reply for two seconds reveals Reply All.
//

import SwiftUI

struct EmailTriageView: View {
    @StateObject private var store = EmailTriageStore.shared

    // Reply -> Reply All hover reveal.
    @State private var showReplyAll = false
    @State private var replyHoverTask: Task<Void, Never>?

    private let replyHoverDelay: Duration = .seconds(2)

    var body: some View {
        VStack(spacing: 12) {
            headerRow
            HStack(alignment: .center, spacing: 12) {
                navButton(system: "arrow.left", enabled: store.canGoBack) { store.goBack() }
                messageArea
                navButton(system: "arrow.right", enabled: store.canGoForward) { store.goForward() }
            }
            actionRow
        }
        .padding()
        .frame(width: openNotchSize.width)
        .task { await store.loadInboxIfNeeded() }
    }

    // MARK: - Header (counter + refresh)

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("Email")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            if !store.isEmpty {
                Text("\(store.index + 1) of \(store.messages.count)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.gray)
            }
            Spacer()
            if store.isLoading || store.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            Button {
                Task { await store.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.small)
                    .foregroundStyle(.gray)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Refresh inbox")
        }
    }

    // MARK: - Message area (Mail-style card / empty / error)

    @ViewBuilder
    private var messageArea: some View {
        Group {
            if let error = store.errorText, store.isEmpty {
                infoCard(title: "Can't reach Mail", detail: error, systemImage: "exclamationmark.triangle.fill")
            } else if store.isEmpty {
                infoCard(title: store.isLoading ? "Loading…" : "Inbox zero", detail: store.isLoading ? "" : "Nothing left to triage.", systemImage: "tray")
            } else if let message = store.current {
                messageCard(message)
            } else {
                infoCard(title: "Inbox zero", detail: "Nothing left to triage.", systemImage: "tray")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func messageCard(_ message: MailMessage) -> some View {
        Button {
            Task { await store.openInMail() }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(message.senderName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(message.subject.isEmpty ? "(No subject)" : message.subject)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(store.body.isEmpty ? "…" : store.body)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .help("Open in Mail")
    }

    private func infoCard(title: String, detail: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white, .gray)
                .imageScale(.large)
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: - Navigation arrows

    private func navButton(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(enabled ? 0.14 : 0.05)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(alignment: .top, spacing: 18) {
            roundButton(system: "archivebox.fill", tint: Color.blue, help: "Archive") {
                Task { await store.archive() }
            }
            roundButton(system: "trash.fill", tint: Color.red, help: "Delete") {
                Task { await store.delete() }
            }
            replyColumn
            roundButton(system: "arrowshape.turn.up.right.fill", tint: Color.gray, help: "Forward") {
                Task { await store.forward() }
            }
        }
        .disabled(store.current == nil || store.isBusy)
        .opacity(store.current == nil ? 0.4 : 1)
    }

    /// Reply button that reveals a Reply All button beneath it after a 2s hover.
    private var replyColumn: some View {
        VStack(spacing: 10) {
            roundButton(system: "arrowshape.turn.up.left.fill", tint: Color.accentColor, help: "Reply") {
                Task { await store.reply(all: false) }
            }
            if showReplyAll {
                roundButton(system: "arrowshape.turn.up.left.2.fill", tint: Color.accentColor.opacity(0.75), help: "Reply All") {
                    Task { await store.reply(all: true) }
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .onHover { hovering in
            if hovering {
                replyHoverTask?.cancel()
                replyHoverTask = Task { @MainActor in
                    try? await Task.sleep(for: replyHoverDelay)
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showReplyAll = true }
                }
            } else {
                replyHoverTask?.cancel()
                replyHoverTask = nil
                withAnimation(.easeOut(duration: 0.15)) { showReplyAll = false }
            }
        }
        .animation(.smooth, value: showReplyAll)
    }

    private func roundButton(system: String, tint: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(tint))
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

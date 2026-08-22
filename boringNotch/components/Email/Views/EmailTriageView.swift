//
//  EmailTriageView.swift
//  boringNotch
//
//  The Email triage tab. Steps through the Apple Mail inbox with back/forward
//  arrows, shows the current message Mail-style (bold sender / subject / grey
//  preview, left aligned) on a light card, and offers a row of round triage
//  actions the user configures in Settings › Email (Archive / Delete / Reply /
//  Reply All / Forward / Open in Mail).
//

import Defaults
import SwiftUI

struct EmailTriageView: View {
    @StateObject private var store = EmailTriageStore.shared
    @Default(.emailActionSlots) private var actionSlots

    var body: some View {
        VStack(spacing: 8) {
            headerRow
            HStack(alignment: .center, spacing: 10) {
                navButton(system: "arrow.left", enabled: store.canGoBack) { store.goBack() }
                messageArea
                navButton(system: "arrow.right", enabled: store.canGoForward) { store.goForward() }
            }
            actionRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func messageCard(_ message: MailMessage) -> some View {
        Button {
            Task { await store.openInMail() }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(message.senderName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(message.subject.isEmpty ? "(No subject)" : message.subject)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(store.body.isEmpty ? "…" : store.body)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation arrows

    private func navButton(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(enabled ? 0.14 : 0.05)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    // MARK: - Action row (user-configured slots)

    private var actionRow: some View {
        // Only the filled slots take part, so an all-empty configuration collapses
        // gracefully rather than leaving a row of gaps.
        let actions = actionSlots.filter { $0 != .none }
        return HStack(spacing: 18) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                actionButton(action)
            }
        }
        .disabled(store.current == nil || store.isBusy)
        .opacity(store.current == nil ? 0.4 : 1)
    }

    @ViewBuilder
    private func actionButton(_ action: EmailActionButton) -> some View {
        roundButton(system: action.iconName, tint: action.tint, help: action.label) {
            Task { await perform(action) }
        }
    }

    private func perform(_ action: EmailActionButton) async {
        switch action {
        case .archive: await store.archive()
        case .delete: await store.delete()
        case .reply: await store.reply(all: false)
        case .replyAll: await store.reply(all: true)
        case .forward: await store.forward()
        case .openInMail: await store.openInMail()
        case .none: break
        }
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

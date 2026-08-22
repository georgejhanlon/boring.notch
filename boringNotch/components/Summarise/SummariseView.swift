//
//  SummariseView.swift
//  boringNotch
//
//  Shows the streamed summary in the notch, with a dismiss (✕) and a button to
//  continue the topic in the Claude chat tab.
//

import SwiftUI

struct SummariseView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @StateObject private var store = SummariseStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            content
            footer
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.claudeOrange)
                .imageScale(.small)
            Text("Summary")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            if store.state == .capturing || store.state == .summarising {
                ProgressView().controlSize(.small).progressViewStyle(.circular)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .capturing:
            centered("Grabbing your selection…")
        case .summarising, .done:
            ScrollView {
                Text(store.summary.isEmpty ? "…" : store.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.92))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            centered(message, isError: true)
        }
    }

    private func centered(_ text: String, isError: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(isError ? .red : .gray)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                let context = store.sourceText.isEmpty
                    ? "Let's discuss the thing I just summarised."
                    : "Let's discuss this in more detail:\n\n\(store.sourceText)"
                ClaudeChatStore.shared.startChat(with: context)
                withAnimation(.smooth) { coordinator.currentView = .claude }
            } label: {
                Label("Chat in Claude", systemImage: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.claudeOrange)
            .disabled(store.state == .capturing)

            Spacer()

            Button {
                withAnimation(.smooth) { coordinator.currentView = .home }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
    }
}

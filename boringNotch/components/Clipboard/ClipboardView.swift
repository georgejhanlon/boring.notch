//
//  ClipboardView.swift
//  boringNotch
//
//  The Clipboard history tab: a scrollable list of recent copies. Click one to
//  copy it back to the pasteboard.
//

import SwiftUI

struct ClipboardView: View {
    @StateObject private var manager = ClipboardManager.shared
    @State private var justCopied: UUID?

    /// Set from ContentView so scroll/hover over the history suppresses the notch
    /// close gesture (mirrors the Checklist/Calendar convention).
    @Binding var isHovering: Bool

    init(isHovering: Binding<Bool> = .constant(false)) {
        self._isHovering = isHovering
    }

    var body: some View {
        VStack(spacing: 6) {
            header
            if manager.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active: isHovering = true
            case .ended: isHovering = false
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.white)
                .imageScale(.small)
            Text("Clipboard")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            if !manager.items.isEmpty {
                Text("\(manager.items.count)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.gray)
            }
            Spacer()
            if !manager.items.isEmpty {
                HoldToDeleteButton(help: "Hold to clear history") {
                    manager.clear()
                }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 5) {
                ForEach(manager.items) { item in
                    row(item)
                }
            }
            .padding(.vertical, 2)
            // Keep the copy button clear of the scroll indicator.
            .padding(.trailing, 6)
        }
    }

    private func row(_ item: ClipItem) -> some View {
        Button {
            manager.copy(item)
            justCopied = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                if justCopied == item.id { justCopied = nil }
            }
        } label: {
            HStack(spacing: 8) {
                if let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 34, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    Text("Image")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                } else {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                        .frame(width: 16)
                    Text(item.text ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.9))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 4)
                Image(systemName: justCopied == item.id ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(justCopied == item.id ? .green : .gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white, .gray)
                .imageScale(.large)
            Text("Nothing copied yet")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text("Copy anything and it shows up here.")
                .font(.system(size: 10))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

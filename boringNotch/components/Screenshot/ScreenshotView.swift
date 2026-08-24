//
//  ScreenshotView.swift
//  boringNotch
//
//  The Screenshot tab: capture buttons on the left (window / full screen — a
//  shortcut for the macOS screenshot tools), a content-named history on the
//  right. History rows are selectable (⌘/⇧ for multiple) and can be dragged
//  out — onto the Shelf, Finder, or any app — as the underlying files.
//

import SwiftUI

struct ScreenshotView: View {
    @StateObject private var manager = ScreenshotManager.shared

    /// Multi-selection of history rows, keyed by file URL (the item id).
    @State private var selection = Set<URL>()

    /// Set from ContentView so scroll/hover over the history suppresses the
    /// notch close gesture (mirrors the Clipboard/Checklist convention).
    @Binding var isHovering: Bool

    init(isHovering: Binding<Bool> = .constant(false)) {
        self._isHovering = isHovering
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            captureColumn
            Divider().overlay(Color.white.opacity(0.12))
            historyColumn
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onAppear { manager.refresh() }
        .onContinuousHover { phase in
            switch phase {
            case .active: isHovering = true
            case .ended: isHovering = false
            }
        }
    }

    // MARK: - Left: capture buttons

    private var captureColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)

            captureButton(title: "Window", systemImage: "macwindow", mode: .window)
            captureButton(title: "Full Screen", systemImage: "rectangle.inset.filled", mode: .fullScreen)

            Spacer(minLength: 0)

            Text("Drag items to the Shelf or Finder. ⌘-click for more than one.")
                .font(.system(size: 9))
                .foregroundStyle(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 130, alignment: .leading)
    }

    private func captureButton(title: String, systemImage: String, mode: ScreenshotManager.Mode) -> some View {
        Button {
            manager.capture(mode)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .imageScale(.medium)
                    .frame(width: 18)
                Text(title)
                    .font(.system(.body, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disabled(manager.isBusy)
        .opacity(manager.isBusy ? 0.5 : 1)
    }

    // MARK: - Right: history

    private var historyColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("History")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                if !manager.items.isEmpty {
                    Text("\(manager.items.count)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.gray)
                }
                Spacer()
                Button { manager.openFolder() } label: {
                    Image(systemName: "folder")
                        .imageScale(.small).foregroundStyle(.gray).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open Screenshots folder")
            }

            if manager.items.isEmpty {
                emptyState
            } else {
                List(selection: $selection) {
                    ForEach(manager.items) { item in
                        row(item)
                            .draggable(item.url)
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded { manager.open(item) }
                            )
                            .contextMenu {
                                Button("Open") { manager.open(item) }
                                Button("Show in Finder") { manager.reveal(item) }
                                Divider()
                                Button("Delete", role: .destructive) { delete(item) }
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .environment(\.defaultMinListRowHeight, 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func delete(_ item: ScreenshotItem) {
        selection.remove(item.url)
        manager.delete(item)
    }

    private func row(_ item: ScreenshotItem) -> some View {
        HStack(spacing: 8) {
            Group {
                if let image = manager.thumbnail(for: item) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: 40, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            Text(item.name)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.9))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "camera.viewfinder")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white, .gray)
                .imageScale(.large)
            Text("No screenshots yet")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text("Capture one and it shows up here, auto-named.")
                .font(.system(size: 10))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

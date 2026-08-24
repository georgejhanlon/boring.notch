//
//  ScreenshotView.swift
//  boringNotch
//
//  The Screenshot tab: capture buttons on the left (selection / full screen /
//  timed), a content-named history on the right. History rows are selectable
//  (⌘/⇧ for multiple) and can be dragged out — onto the Shelf, Finder, or any
//  app — as the underlying files.
//

import AppKit
import SwiftUI

struct ScreenshotView: View {
    @StateObject private var manager = ScreenshotManager.shared

    /// Multi-selection of history rows, keyed by file URL (the item id).
    @State private var selection = Set<URL>()
    /// Anchor for ⇧-range selection.
    @State private var anchor: URL?

    /// Delay (seconds) for the timed capture.
    @State private var timerSeconds = 5

    /// Row currently under the pointer (shows its delete control).
    @State private var hoveredItem: URL?

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

            captureButton(title: "Selection", systemImage: "rectangle.dashed") {
                manager.capture(.window)
            }
            captureButton(title: "Full Screen", systemImage: "rectangle.inset.filled") {
                manager.capture(.fullScreen)
            }
            timerButton

            Spacer(minLength: 0)
        }
        .frame(width: 164, alignment: .leading)
    }

    /// Timed full-screen capture with an inline "+ N −" stepper.
    private var timerButton: some View {
        HStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "timer").imageScale(.medium).frame(width: 16)
                Text("Timer")
                    .font(.system(.body, design: .rounded))
                    .fixedSize()
            }
            .contentShape(Rectangle())
            .onTapGesture { manager.capture(.fullScreen, delay: timerSeconds) }

            Spacer(minLength: 2)

            secondsStep("plus") { timerSeconds += 1 }
            Text("\(timerSeconds)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(minWidth: 14)
                .monospacedDigit()
            secondsStep("minus") { timerSeconds = max(1, timerSeconds - 1) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))
        .opacity(manager.isBusy ? 0.5 : 1)
    }

    private func secondsStep(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }

    private func captureButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(manager.items) { item in
                            row(item)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 6)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ item: ScreenshotItem) -> some View {
        let selected = selection.contains(item.url)
        let hovered = hoveredItem == item.url
        return ZStack {
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.06))
            )

            ScreenshotRowInteraction(
                isSelected: { selection.contains(item.url) },
                onSelect: { mods in handleSelect(item, modifiers: mods) },
                onOpen: { manager.open(item) },
                onReveal: { manager.reveal(item) },
                onDelete: { delete(item) },
                dragURLs: { dragURLs(for: item) },
                preview: { manager.thumbnail(for: item) }
            )

            // Hover-only delete on the trailing edge: 1s hold, red sweep.
            if hovered {
                HStack {
                    Spacer()
                    HoldToDeleteButton(duration: 1, help: "Hold to delete") {
                        delete(item)
                    }
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.black.opacity(0.55)))
                    .padding(.trailing, 8)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering { hoveredItem = item.url }
            else if hoveredItem == item.url { hoveredItem = nil }
        }
    }

    // MARK: - Selection

    private func handleSelect(_ item: ScreenshotItem, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.command) {
            if selection.contains(item.url) { selection.remove(item.url) } else { selection.insert(item.url) }
            anchor = item.url
        } else if modifiers.contains(.shift), let anchor,
                  let a = manager.items.firstIndex(where: { $0.url == anchor }),
                  let b = manager.items.firstIndex(where: { $0.url == item.url }) {
            let range = manager.items[min(a, b)...max(a, b)]
            selection = Set(range.map { $0.url })
        } else {
            selection = [item.url]
            anchor = item.url
        }
    }

    private func dragURLs(for item: ScreenshotItem) -> [URL] {
        if selection.contains(item.url) && selection.count > 1 {
            return manager.items.filter { selection.contains($0.url) }.map { $0.url }
        }
        return [item.url]
    }

    private func delete(_ item: ScreenshotItem) {
        selection.remove(item.url)
        manager.delete(item)
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

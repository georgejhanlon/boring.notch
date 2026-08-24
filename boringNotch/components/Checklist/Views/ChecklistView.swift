//
//  ChecklistView.swift
//  boringNotch
//
//  The Checklist panel. Renders active items, an expand/collapse arrow that lets
//  the notch resize to fit, a top-right "recent" history disclosure, and an
//  optional completed section. Completing an item swooshes it off the trailing
//  edge. Also used for the always-on layout beneath the notch.
//

import SwiftUI
import AppKit
import Defaults

struct ChecklistView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject private var store = ChecklistStore.shared

    /// Set from ContentView so scroll/hover over the checklist suppresses the
    /// notch close gesture (mirrors the Calendar convention).
    @Binding var isHovering: Bool

    /// Upper bound for the active list's scroll area, so the notch stays within
    /// its window. Always-on mode passes a larger value.
    let maxListHeight: CGFloat

    @Default(.checklistShowCompleted) private var showCompleted
    @Default(.checklistDefaultName) private var defaultName
    @Default(.checklistAnimationSpeed) private var animationSpeed
    @Default(.checklistAlwaysOn) private var alwaysOn

    @State private var expanded = true
    @State private var showRecent = false
    @State private var showCompletedSection = false
    @State private var isAddingItem = false
    @State private var newItemText = ""
    @FocusState private var addFieldFocused: Bool

    private let spacing: CGFloat = 8

    init(isHovering: Binding<Bool> = .constant(false), maxListHeight: CGFloat = 120) {
        self._isHovering = isHovering
        self.maxListHeight = maxListHeight
    }

    var body: some View {
        panel
            .onHover { hovering in isHovering = hovering }
    }

    private var panel: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10]))
            )
            .transaction { transaction in
                transaction.animation = vm.animation
            }
            .contentShape(Rectangle())
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.isEmpty {
                emptyHeader
            } else {
                header
            }

            // Kept outside the empty/loaded branch so its identity — and the
            // keyboard focus — survives adding the first item to an empty list.
            if isAddingItem {
                addItemField
            }

            if !store.isEmpty {
                if showRecent {
                    recentList
                }
                if expanded {
                    activeList
                    if showCompleted && !store.checklist.completedItems.isEmpty {
                        completedDisclosure
                    }
                }
            }
        }
        .background(NotchKeyFocusEnabler(isEditing: isAddingItem))
        .animation(.smooth, value: expanded)
        .animation(.smooth, value: showRecent)
        .animation(.smooth, value: showCompletedSection)
        .animation(.smooth, value: isAddingItem)
        .animation(.smooth, value: store.isEmpty)
    }

    // MARK: - Header (arrow left, name, recent top-right)

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.smooth) { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .imageScale(.small)
                    .foregroundStyle(.gray)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(store.checklist.displayName(default: defaultName))
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            // Little always-on toggle beside the name — pins the checklist strip
            // inside the notch (item 7). Only shown when there is a checklist.
            if !store.isEmpty {
                Button {
                    withAnimation(.smooth) { alwaysOn.toggle() }
                } label: {
                    Image(systemName: alwaysOn ? "pin.fill" : "pin")
                        .imageScale(.small)
                        .foregroundStyle(alwaysOn ? Color.accentColor : .gray)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Keep the checklist visible in the notch")

                HoldToDeleteButton(help: "Hold to clear the current checklist") {
                    withAnimation(.smooth) { store.clearCurrent() }
                }

                // Small add button beside the bin — append a custom item by hand.
                Button {
                    startAdding()
                } label: {
                    Image(systemName: "plus")
                        .imageScale(.small)
                        .foregroundStyle(isAddingItem ? Color.accentColor : .gray)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Add a checklist item")
            }

            Spacer(minLength: 8)

            Button {
                withAnimation(.smooth) { showRecent.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text("recent")
                        .font(.system(.subheadline, design: .rounded))
                    Image(systemName: showRecent ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                }
                .foregroundStyle(.gray)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Active list (with completion swoosh)

    private var activeList: some View {
        // Items flow left-to-right and wrap to the next row before the list needs
        // to scroll down.
        ScrollView(.vertical) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: spacing, alignment: .leading)],
                alignment: .leading,
                spacing: spacing
            ) {
                ForEach(store.checklist.activeItems) { item in
                    row(for: item)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .trailing)
                                .combined(with: .scale(scale: 0.85))
                                .combined(with: .opacity)
                        ))
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.never)
        .frame(maxHeight: maxListHeight)
    }

    private var completedDisclosure: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Button {
                withAnimation(.smooth) { showCompletedSection.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showCompletedSection ? "chevron.down" : "chevron.right")
                        .imageScale(.small)
                    Text("completed")
                        .font(.system(.subheadline, design: .rounded))
                    Text("\(store.checklist.completedItems.count)")
                    Spacer()
                }
                .foregroundStyle(.gray)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showCompletedSection {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 130), spacing: spacing, alignment: .leading)],
                    alignment: .leading,
                    spacing: spacing
                ) {
                    ForEach(store.checklist.completedItems) { item in
                        row(for: item)
                    }
                }
            }
        }
    }

    private func row(for item: ChecklistItem) -> some View {
        Button {
            withAnimation(.spring(response: animationSpeed.response, dampingFraction: 0.7)) {
                store.toggle(item)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.done ? Color.accentColor : .gray)
                    .imageScale(.large)
                Text(item.text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(item.done ? .gray : .white)
                    .strikethrough(item.done, color: .gray)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent history disclosure body

    private var recentList: some View {
        Group {
            if store.recentArchives.isEmpty {
                Text("No history")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.gray)
            } else {
                VStack(alignment: .leading, spacing: spacing) {
                    ForEach(store.recentArchives) { archive in
                        recentRow(for: archive)
                    }
                }
            }
        }
    }

    private func recentRow(for archive: ArchivedChecklist) -> some View {
        Button {
            store.loadFromHistory(archive)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .imageScale(.small)
                    .foregroundStyle(.gray)
                Text(archive.name)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(Self.relativeString(from: archive.date))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.gray)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static func relativeString(from date: Date) -> String {
        if Calendar.current.isDateInYesterday(date) { return "yesterday" }
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Empty state (left-aligned custom-checklist affordance)

    private var emptyHeader: some View {
        HStack(spacing: 10) {
            // Left: start a checklist by hand, no external (Claude) file needed.
            Button {
                startAdding()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .imageScale(.large)
                    Text("Custom checklist")
                        .foregroundStyle(.white)
                        .font(.system(.headline, design: .rounded))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Start a checklist by hand")

            Spacer(minLength: 8)

            Text("No checklist")
                .foregroundStyle(.gray)
                .font(.system(.subheadline, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Add-item field

    private var addItemField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .imageScale(.large)
            TextField("Add item…", text: $newItemText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .focused($addFieldFocused)
                .onSubmit { commitNewItem() }
            Button {
                stopAdding()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.gray)
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .help("Done adding")
        }
        .contentShape(Rectangle())
    }

    private func startAdding() {
        withAnimation(.smooth) { isAddingItem = true }
        // Defer focus one runloop tick so the field (and key window) exist.
        DispatchQueue.main.async { addFieldFocused = true }
    }

    private func commitNewItem() {
        let text = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            stopAdding()
            return
        }
        withAnimation(.smooth) { store.addItem(text) }
        newItemText = ""
        // Keep the field up and focused for rapid multi-item entry.
        addFieldFocused = true
    }

    private func stopAdding() {
        newItemText = ""
        addFieldFocused = false
        withAnimation(.smooth) { isAddingItem = false }
    }
}

// MARK: - Temporarily let the notch window take keyboard focus while editing

/// The notch's SkyLight window refuses key status so it never steals focus.
/// While the add field is active we flip that on and make the window key so the
/// `TextField` can receive typing, restoring the default when editing ends.
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
}

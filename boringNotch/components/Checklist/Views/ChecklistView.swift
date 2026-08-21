//
//  ChecklistView.swift
//  boringNotch
//
//  The open-notch Checklist panel. Renders the full list, or — when collapsed —
//  only the current unticked item.
//

import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject private var store = ChecklistStore.shared
    @State private var collapsed = false
    @State private var showRecent = false

    private let spacing: CGFloat = 8

    var body: some View {
        panel
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10]))
            .overlay {
                content
                    .padding()
            }
            .transaction { transaction in
                transaction.animation = vm.animation
            }
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        if store.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 10) {
                header
                if collapsed {
                    collapsedRow
                } else {
                    list
                    recentDisclosure
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(store.checklist.title.isEmpty ? "Checklist" : store.checklist.title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button {
                withAnimation(.smooth) { collapsed.toggle() }
            } label: {
                Image(systemName: collapsed ? "chevron.down" : "chevron.up")
                    .foregroundStyle(.gray)
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var collapsedRow: some View {
        if let current = store.currentItem {
            row(for: current)
        } else {
            Text("All done")
                .foregroundStyle(.gray)
                .font(.system(.body, design: .rounded))
        }
    }

    private var list: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: spacing) {
                ForEach(store.checklist.items) { item in
                    row(for: item)
                }
            }
        }
        .scrollIndicators(.never)
    }

    private func row(for item: ChecklistItem) -> some View {
        Button {
            store.toggle(item)
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

    private var recentDisclosure: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Button {
                withAnimation(.smooth) { showRecent.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showRecent ? "chevron.down" : "chevron.right")
                        .imageScale(.small)
                    Text("recent")
                        .font(.system(.subheadline, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(.gray)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showRecent {
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white, .gray)
                .imageScale(.large)
            Text("No checklist")
                .foregroundStyle(.gray)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

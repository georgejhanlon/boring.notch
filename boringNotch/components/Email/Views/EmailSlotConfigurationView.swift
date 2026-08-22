//
//  EmailSlotConfigurationView.swift
//  boringNotch
//
//  Drag-to-arrange configuration for the Email tab's action row, mirroring the
//  music player's slot configuration. Drag a control from the palette onto a
//  slot, drag slots to reorder, or drop onto the trash to clear a slot.
//

import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct EmailSlotConfigurationView: View {
    @Default(.emailActionSlots) private var slots
    @State private var draggedSlot: EmailActionButton?

    private let slotCount = EmailActionButton.slotCount

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            slotConfigurationSection

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    withAnimation {
                        slots = EmailActionButton.defaultLayout
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .onAppear { ensureSlotCapacity(slotCount) }
    }

    private var slotConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Layout Preview")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Drag items in the preview to reorder or drop from the palette")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            previewSection

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Drag a control onto a slot")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(minimum: 44), spacing: 8),
                        count: 6
                    ),
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(EmailActionButton.pickerOptions, id: \.self) { control in
                        paletteControl(for: control)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var previewSection: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0..<slotCount, id: \.self) { index in
                    let slot = slotValue(at: index)
                    Group {
                        if slot != .none {
                            slotPreview(for: slot)
                                .frame(maxWidth: 44)
                                .onDrag {
                                    DispatchQueue.main.async { draggedSlot = slot }
                                    return NSItemProvider(object: NSString(string: "slot:\(index)"))
                                }
                                .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                                    let handled = handleDrop(providers, toIndex: index)
                                    DispatchQueue.main.async { draggedSlot = nil }
                                    return handled
                                }
                        } else {
                            slotPreview(for: slot)
                                .frame(maxWidth: 44)
                                .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                                    let handled = handleDrop(providers, toIndex: index)
                                    DispatchQueue.main.async { draggedSlot = nil }
                                    return handled
                                }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(width: 56, height: 56)

                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
                .cornerRadius(10)
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                    handleDropOnTrash(providers)
                }

                Text("Clear slot")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 72)
            }
        }
    }

    private func paletteControl(for control: EmailActionButton) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 44, height: 44)

                Image(systemName: control.iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(control.tint == .clear ? Color.primary : control.tint)
                    .frame(width: 28, height: 28)
            }
            .cornerRadius(8)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onDrag {
                NSItemProvider(object: NSString(string: "control:\(control.rawValue)"))
            }
            .onTapGesture {
                if let index = slots.firstIndex(of: .none) {
                    updateSlot(control, at: index)
                } else {
                    withAnimation { updateSlot(control, at: 0) }
                }
            }

            Text(control.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func slotPreview(for slot: EmailActionButton) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .frame(width: 44, height: 44)

            if slot != .none {
                Image(systemName: slot.iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(slot.tint == .clear ? Color.primary : slot.tint)
                    .frame(width: 28, height: 28)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .frame(width: 32, height: 32)
            }
        }
        .cornerRadius(8)
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Slot helpers

    private func ensureSlotCapacity(_ target: Int) {
        guard target > slots.count else { return }
        slots.append(contentsOf: Array(repeating: .none, count: target - slots.count))
    }

    private func slotValue(at index: Int) -> EmailActionButton {
        guard slots.indices.contains(index) else { return .none }
        return slots[index]
    }

    private func updateSlot(_ value: EmailActionButton, at index: Int) {
        var updated = slots
        if index >= updated.count {
            updated.append(contentsOf: Array(repeating: .none, count: index - updated.count + 1))
        }
        updated[index] = value
        slots = updated
    }

    // MARK: - Drag & drop

    private func handleDrop(_ providers: [NSItemProvider], toIndex: Int) -> Bool {
        for provider in providers where provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { item, _ in
                let raw = (item as? NSString).map(String.init) ?? (item as? String)
                guard let raw else { return }
                DispatchQueue.main.async { processDropString(raw, toIndex: toIndex) }
            }
            return true
        }
        return false
    }

    private func handleDropOnTrash(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { item, _ in
                let raw = (item as? NSString).map(String.init) ?? (item as? String)
                guard let raw, raw.hasPrefix("slot:") else { return }
                DispatchQueue.main.async {
                    let from = Int(raw.dropFirst("slot:".count)) ?? -1
                    guard slots.indices.contains(from) else { return }
                    var updated = slots
                    updated[from] = .none
                    slots = updated
                }
            }
            return true
        }
        return false
    }

    private func processDropString(_ raw: String, toIndex: Int) {
        if raw.hasPrefix("slot:") {
            let from = Int(raw.dropFirst("slot:".count)) ?? -1
            guard slots.indices.contains(from), slots.indices.contains(toIndex) else { return }
            var updated = slots
            updated.swapAt(from, toIndex)
            slots = updated
        } else if raw.hasPrefix("control:") {
            let val = String(raw.dropFirst("control:".count))
            guard let control = EmailActionButton(rawValue: val) else { return }
            var updated = slots
            // A control can only occupy one slot; clear its previous home first.
            if let existing = updated.firstIndex(of: control), existing != toIndex {
                updated[existing] = .none
            }
            slots = updated
            updateSlot(control, at: toIndex)
        }
    }
}

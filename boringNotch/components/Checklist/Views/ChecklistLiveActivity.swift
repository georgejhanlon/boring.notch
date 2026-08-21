//
//  ChecklistLiveActivity.swift
//  boringNotch
//
//  Compact closed-notch indicator: shows only the current unticked item.
//

import SwiftUI

struct ChecklistLiveActivity: View {
    @ObservedObject private var store = ChecklistStore.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checklist")
                .foregroundStyle(.gray)
                .imageScale(.small)
            if let current = store.currentItem {
                Text(current.text)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .foregroundStyle(.gray)
    }
}

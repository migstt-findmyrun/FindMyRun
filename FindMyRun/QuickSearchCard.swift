//
//  QuickSearchCard.swift
//  FindMyRun
//

import SwiftUI

struct QuickSearchCard: View {
    let hasFavorites: Bool
    let onFavorites: () -> Void
    let onMaps: () -> Void
    let onList: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            QuickAction(
                icon: "star.fill",
                label: "Favorites",
                color: .yellow,
                enabled: hasFavorites,
                action: onFavorites
            )

            Divider()
                .frame(height: 40)

            QuickAction(
                icon: "map.fill",
                label: "Maps",
                color: .gray,
                enabled: true,
                action: onMaps
            )

            Divider()
                .frame(height: 40)

            QuickAction(
                icon: "list.bullet",
                label: "List",
                color: .gray,
                enabled: true,
                action: onList
            )
        }
        .padding(.vertical, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

private struct QuickAction: View {
    let icon: String
    let label: String
    let color: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(enabled ? color : .gray.opacity(0.4))
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .fontDesign(.rounded)
                    .foregroundStyle(enabled ? .primary : .tertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
    }
}

//
//  HomeSearchBar.swift
//  Spendrift
//
//  Search entry pinned above the ledger. Tapping it pushes the search screen;
//  it never filters in place.
//

import SwiftUI

private extension View {
    /// Liquid Glass capsule on iOS 26: transparent, so the canvas shows straight
    /// through it instead of sitting on a flat tinted fill. Falls back to that
    /// flat fill on earlier systems.
    @ViewBuilder
    func glassSearchCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self
                .background(AppTheme.searchField, in: Capsule())
                .overlay(Capsule().strokeBorder(AppTheme.searchFieldEdge, lineWidth: 1))
        }
    }
}

struct HomeSearchBar: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.ink)
                CyclingSearchPlaceholder()
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.inkSecondary)
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            // Makes the whole capsule the tap target, not just the icon and words.
            .contentShape(Capsule())
            .glassSearchCapsule()
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityLabel(CyclingSearchPlaceholder.accessibilityText)
        .accessibilityIdentifier("homeSearchBar")
    }
}

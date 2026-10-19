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
    /// Shared with the search screen's empty field.
    static let placeholder = "Search transactions, accounts or categories"

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.ink)
                Text(Self.placeholder)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            // Makes the whole capsule the tap target, not just the icon and words.
            .contentShape(Capsule())
            .glassSearchCapsule()
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityLabel(Self.placeholder)
        .accessibilityIdentifier("homeSearchBar")
    }
}

/// Pins the search bar over a tab's content, with optional chrome under it, and
/// pushes the search screen when tapped. Every tab carries it, because search
/// covers transactions, categories, accounts and merchants from anywhere.
private struct LedgerSearchHeader<Accessory: View>: ViewModifier {
    let accessory: Accessory
    @State private var showSearch = false

    func body(content: Content) -> some View {
        content
            .scrollingHeaderBar {
                VStack(spacing: 10) {
                    HomeSearchBar { showSearch = true }
                    accessory
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            .navigationDestination(isPresented: $showSearch) {
                SearchScreen()
            }
    }
}

extension View {
    /// Search bar pinned at the top. Must sit inside the tab's `NavigationStack`.
    func ledgerSearchHeader() -> some View {
        modifier(LedgerSearchHeader(accessory: EmptyView()))
    }

    /// Search bar with `accessory` pinned under it, such as the Transactions month row.
    func ledgerSearchHeader<Accessory: View>(
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        modifier(LedgerSearchHeader(accessory: accessory()))
    }
}

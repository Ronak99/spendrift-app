//
//  LedgerToolbar.swift
//  Spendrift
//
//  One title bar for the four tabs: the tab's title at the leading edge, and the
//  add and Settings plates together at the trailing edge, so Settings is one tap
//  away on every screen.
//

import SwiftUI

/// Leading title plus the trailing add and Settings plates.
struct LedgerToolbar: ToolbarContent {
    let title: String
    /// VoiceOver name of the add plate, for example "Add transaction".
    let addAccessibilityLabel: String
    var addAccessibilityIdentifier: String? = nil
    let onAdd: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .navigationBarLeading) {
                LedgerTitle(title: title)
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .navigationBarTrailing) {
                actions
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigationBarLeading) {
                LedgerTitle(title: title)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                actions
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            LedgerAddButton(
                accessibilityLabel: addAccessibilityLabel,
                accessibilityIdentifier: addAccessibilityIdentifier,
                action: onAdd
            )
            ProfileSettingsToolbarButton()
        }
    }
}

/// Title text at the leading edge of the navigation bar.
struct LedgerTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 22, weight: .semibold))
            .tracking(-0.4)
            .foregroundStyle(AppTheme.ink)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("homeTitle")
    }
}

/// The one inverted plate on screen: it creates whatever the tab lists.
struct LedgerAddButton: View {
    let accessibilityLabel: String
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.actionForeground)
                .frame(width: 32, height: 32)
                .background(AppTheme.actionBackground, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier ?? "plus")
    }
}

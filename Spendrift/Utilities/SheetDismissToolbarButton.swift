//
//  SheetDismissToolbarButton.swift
//  Spendrift
//

import SwiftUI

/// Standard leading toolbar control for dismissing a sheet.
///
/// Circular chrome plate so the cross stays tappable on iOS versions where the
/// drag-to-dismiss gesture is unreliable. Secondary weight on purpose: Plus and
/// Save own the inverted chrome, Close sits behind them.
struct SheetDismissToolbarButton: View {
    var action: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Button {
            if let action {
                action()
            } else {
                dismiss()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(glyph)
                .frame(width: 32, height: 32)
                .background(plate, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .accessibilityIdentifier("xmark")
    }

    private var plate: Color {
        isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
    }

    private var glyph: Color {
        isDark ? Color.white.opacity(0.8) : Color(hex: "#111111").opacity(0.7)
    }
}

/// Drop-in `.cancellationAction` slot for every sheet presented inside a
/// `NavigationStack`, so the Close plate is the only chrome under Liquid Glass.
struct SheetDismissToolbarItem: ToolbarContent {
    var action: (() -> Void)?

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .cancellationAction) {
                SheetDismissToolbarButton(action: action)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .cancellationAction) {
                SheetDismissToolbarButton(action: action)
            }
        }
    }
}


/// System close control for sheets that should carry the native chrome rather
/// than the custom plate. On iOS 26 the `.close` role draws the glass cross.
struct SheetCloseToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            SheetCloseToolbarButton()
        }
    }
}

private struct SheetCloseToolbarButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close) {
                dismiss()
            }
            .tint(.white)
            .accessibilityIdentifier("xmark")
        } else {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("xmark")
        }
    }
}

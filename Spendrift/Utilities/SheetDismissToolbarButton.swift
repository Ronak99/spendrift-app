//
//  SheetDismissToolbarButton.swift
//  Spendrift
//

import SwiftUI

/// Standard leading toolbar control for dismissing a sheet.
struct SheetDismissToolbarButton: View {
    var action: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            if let action {
                action()
            } else {
                dismiss()
            }
        } label: {
            Image(systemName: "xmark")
        }
        .font(.system(size: 14, weight: .semibold))
        .accessibilityLabel("Close")
        .accessibilityIdentifier("xmark")
    }
}

//
//  MessageInboxImportBannerView.swift
//  Spendrift
//
//  Dismissible confirmation after silent SMS auto-import, with Undo.
//

import SwiftUI

struct MessageInboxImportBannerView: View {
    let count: Int
    let onUndo: () -> Void
    let onDismiss: () -> Void

    private var title: String {
        count == 1
            ? "1 transaction added from messages"
            : "\(count) transactions added from messages"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "message.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text("Parsed from your bank SMS inbox.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.semibold))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerSize: .init(width: 24, height: 24)))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
    }
}

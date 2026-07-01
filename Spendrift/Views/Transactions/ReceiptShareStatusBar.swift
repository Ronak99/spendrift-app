//
//  ReceiptShareStatusBar.swift
//  Spendrift
//
//  Bottom status bar shown briefly once a transaction is created from a receipt
//  shared into the app (via the Share Extension). Scanning progress itself is
//  surfaced by the compact processing capsule in `TransactionsView`.
//

import SwiftUI

/// What the receipt-share bar is currently communicating.
enum ReceiptShareStatus: Equatable {
    /// Nothing to show.
    case hidden
    /// A transaction was created directly (auto-dismisses).
    case created
}

struct ReceiptShareStatusBar: View {
    let status: ReceiptShareStatus

    var body: some View {
        Group {
            switch status {
            case .hidden:
                EmptyView()
            case .created:
                content(
                    icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.green)
                    },
                    title: "Transaction added",
                    subtitle: "Created from your shared receipt."
                )
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.bouncy, value: status)
    }

    private func content(
        @ViewBuilder icon: () -> some View,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 14) {
            icon()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerSize: .init(width: 24, height: 24)))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#if DEBUG
#Preview("Created") {
    ZStack(alignment: .bottom) {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceiptShareStatusBar(status: .created)
    }
}
#endif

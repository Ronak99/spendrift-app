//
//  MessageInboxImportBannerView.swift
//  Spendrift
//
//  Dismissible confirmation after silent SMS auto-import, with Undo.
//

import SwiftUI

struct MessageInboxImportBannerView: View {
    let count: Int
    /// Messages the free monthly allowance could not cover. The SMS drain runs with no
    /// app on screen, so reporting it here is the only way the user learns that some
    /// messages were left unread rather than silently losing them.
    var blockedCount: Int = 0
    let onUndo: () -> Void
    let onDismiss: () -> Void
    var onUpgrade: (() -> Void)? = nil

    private var isBlockedOnly: Bool { count == 0 && blockedCount > 0 }

    private var title: String {
        if isBlockedOnly {
            return blockedCount == 1
                ? "1 message waiting"
                : "\(blockedCount) messages waiting"
        }
        return count == 1
            ? "1 transaction added from messages"
            : "\(count) transactions added from messages"
    }

    private var subtitle: String {
        if isBlockedOnly {
            return "You're out of free message imports this month."
        }
        if blockedCount > 0 {
            let noun = blockedCount == 1 ? "message" : "messages"
            return "\(blockedCount) more \(noun) waiting — free limit reached."
        }
        return "Parsed from your bank SMS inbox."
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isBlockedOnly ? "message.badge.filled.fill" : "message.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if blockedCount > 0, let onUpgrade {
                Button("Unlock", action: onUpgrade)
                    .font(.subheadline.weight(.semibold))
            }

            // Nothing was created when the drain was blocked outright, so there is
            // nothing to undo.
            if count > 0 {
                Button("Undo", action: onUndo)
                    .font(.subheadline.weight(.semibold))
            }

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

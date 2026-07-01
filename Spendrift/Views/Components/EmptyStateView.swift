//
//  EmptyStateView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

/// Actions for the transactions empty-state **Add Transaction** control when it should match the toolbar add menu.
struct EmptyStateAddTransactionMenu {
    let onSpeak: () -> Void
    let onType: () -> Void
    var onUploadDocument: (() -> Void)? = nil
    var onScanReceipt: (() -> Void)? = nil
    var voiceDisabled: Bool = false
    var typeLabel: String = "Type"
    var speakLabel: String = "Speak"
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    /// When non-nil, `action` is ignored and the primary control becomes a menu (Speak / Type / Upload document).
    var addTransactionMenu: EmptyStateAddTransactionMenu? = nil
    /// Replaces the add menu with a button that triggers a Sentry test crash on tap.
    var debugCrashOnCTATap: Bool = false


    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let actionTitle {
                primaryAction(for: actionTitle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func primaryAction(for actionTitle: String) -> some View {
        #if DEBUG
        if debugCrashOnCTATap {
            primaryButton(title: actionTitle, action: Diagnostics.triggerTestCrash)
        } else if let menu = addTransactionMenu {
            addTransactionMenuButton(title: actionTitle, menu: menu)
        } else if let action {
            primaryButton(title: actionTitle, action: action)
        }
        #else
        if let menu = addTransactionMenu {
            addTransactionMenuButton(title: actionTitle, menu: menu)
        } else if let action {
            primaryButton(title: actionTitle, action: action)
        }
        #endif
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .cornerRadius(10)
        }
        .padding(.top, 8)
    }

    private func addTransactionMenuButton(
        title: String,
        menu: EmptyStateAddTransactionMenu
    ) -> some View {
        Menu {
            Button(action: menu.onType) {
                Label(menu.typeLabel, systemImage: "keyboard")
            }

            Button(action: menu.onSpeak) {
                Label(menu.speakLabel, systemImage: "mic")
            }
            .disabled(menu.voiceDisabled)

            if let onUploadDocument = menu.onUploadDocument {
                Button(action: onUploadDocument) {
                    Label("Upload document", systemImage: "doc.text")
                }
            }

            if let onScanReceipt = menu.onScanReceipt {
                Button(action: onScanReceipt) {
                    Label("Scan receipt", systemImage: "doc.viewfinder")
                }
            }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .cornerRadius(10)
        }
        .padding(.top, 8)
        .menuOrder(.fixed)
        .accessibilityLabel("Add transaction")
        .accessibilityIdentifier("transactionsAddMenu")
    }
}

// MARK: - NeatPass-style Floating CTA for empty state

struct EmptyStateFloatingCTA: View {
    let onAdd: () -> Void
    let onVoice: () -> Void
    var voiceDisabled: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAdd) {
                Label("Add Transaction", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.accentColor))
            }

            Button(action: onVoice) {
                Image(systemName: "mic.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(12)
                    .background(
                        Circle()
                            .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                            .background(Circle().fill(Color.accentColor.opacity(0.1)))
                    )
            }
            .disabled(voiceDisabled)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .padding(.horizontal, 32)
    }
}

#Preview {
    EmptyStateView(
        icon: "tray",
        title: "No Transactions",
        description: "Get started by adding your first transaction",
        action: nil,
        addTransactionMenu: EmptyStateAddTransactionMenu(onSpeak: {}, onType: {}, onUploadDocument: {})
    )
}

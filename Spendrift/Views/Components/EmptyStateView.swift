//
//  EmptyStateView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    /// Optional caption shown under the action button (e.g. "Tap to add · Hold to speak").
    var actionHint: String? = nil
    /// When provided together with `onActionHold`, the action button also supports a
    /// hold-to-speak gesture driven by this shared controller.
    var holdController: HoldToSpeakController? = nil
    var holdEnabled: Bool = true
    var onActionHold: (() -> Void)? = nil

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

            if let actionTitle, let action {
                VStack(spacing: 8) {
                    if let holdController, let onActionHold {
                        HoldToSpeakButton(
                            controller: holdController,
                            holdEnabled: holdEnabled,
                            onTap: action,
                            onHoldComplete: onActionHold
                        ) {
                            actionLabel(actionTitle)
                        }
                        .accessibilityLabel(actionTitle)
                        .accessibilityIdentifier(actionTitle)
                    } else {
                        Button(action: action) {
                            actionLabel(actionTitle)
                        }
                    }

                    if let actionHint {
                        Text(actionHint)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .cornerRadius(10)
    }
}

#Preview {
    EmptyStateView(
        icon: "tray",
        title: "No Transactions",
        description: "Get started by adding your first transaction",
        actionTitle: "Add Transaction",
        action: {}
    )
}

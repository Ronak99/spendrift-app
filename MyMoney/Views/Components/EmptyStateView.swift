//
//  EmptyStateView.swift
//  MyMoney
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
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
        description: "Get started by adding your first transaction"
    )
    .overlay(alignment: .bottom) {
        EmptyStateFloatingCTA(onAdd: {}, onVoice: {})
            .padding(.bottom, 24)
    }
}

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
        .padding(.bottom, 24)
        .background(AppTheme.listBackground)
    }
}

/// Frame for whatever stands in for an empty list: a create row on a Home pane or
/// the "No transactions" note on a ledger sheet. Every empty state sits at these
/// margins under its header and scrolls like the list it replaces.
struct EmptyStateContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 18)
        }
        .scrollIndicators(.hidden)
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

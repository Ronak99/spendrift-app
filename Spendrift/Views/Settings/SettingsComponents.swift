//
//  SettingsComponents.swift
//  Spendrift
//
//  Shared tokens and chrome for settings screens.
//

import SwiftUI
import UIKit

enum SettingsTokens {
    static let groupCard = AppTheme.listGroupBackground
    static let chevron = Color(uiColor: .tertiaryLabel)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    static let iconSize: CGFloat = 44
    static let iconGap: CGFloat = 16
}

struct SettingsIconTile: View {
    let systemName: String
    let accent: Color
    let accentSoft: Color
    var size: CGFloat = SettingsTokens.iconSize
    var symbolSize: CGFloat = 20

    var body: some View {
        Circle()
            .fill(accentSoft)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(accent)
            }
    }
}

struct SettingsScreen<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        List {
            content
        }
        .listStyle(.insetGrouped)
        .softScrollEdge()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

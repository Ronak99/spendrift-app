//
//  SettingsComponents.swift
//  Spendrift
//
//  Shared grouped-inset building blocks for the settings screen and its drill-ins.
//

import SwiftUI
import UIKit

enum SettingsTokens {
    static let screenBackground = AppTheme.listBackground
    static let groupCard = AppTheme.listGroupBackground
    static let chevron = Color(uiColor: .tertiaryLabel)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let divider = Color(uiColor: .separator).opacity(0.35)
    static let rowPressHighlight = Color(uiColor: .quaternarySystemFill)

    static let screenInset: CGFloat = 16
    static let cardRadius: CGFloat = 22
    static let rowHeight: CGFloat = 52
    static let rowLeading: CGFloat = 16
    static let rowTrailing: CGFloat = 16
    static let iconSize: CGFloat = 30
    static let iconGap: CGFloat = 12
    /// Where a divider starts: card inset + icon tile + gap.
    static let dividerInset: CGFloat = rowLeading + iconSize + iconGap
}

struct SettingsIconTile: View {
    let systemName: String
    let accent: Color
    let accentSoft: Color
    var size: CGFloat = SettingsTokens.iconSize
    var cornerRadius: CGFloat = 8
    var symbolSize: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(accentSoft)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(accent)
            }
    }
}

struct SettingsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? SettingsTokens.rowPressHighlight : Color.clear)
    }
}

struct SettingsRow: View {
    enum Accessory {
        case plain
        case toggle(Binding<Bool>)
        case value(String)
        case valueChevron(String)
        case chevron
        case externalLink
    }

    /// `nil` leaves the icon slot empty so the row indents under its parent (the reminder time row).
    let icon: String?
    let title: String
    var subtitle: String?
    let accent: Color
    let accentSoft: Color
    var accessory: Accessory = .chevron
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(SettingsPressStyle())
        } else {
            content
        }
    }

    var content: some View {
        HStack(spacing: SettingsTokens.iconGap) {
            if let icon {
                SettingsIconTile(systemName: icon, accent: accent, accentSoft: accentSoft)
            } else {
                Color.clear.frame(width: SettingsTokens.iconSize, height: 1)
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundStyle(SettingsTokens.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(SettingsTokens.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                accessoryView
            }
            .padding(.vertical, subtitle == nil ? 0 : 8)
            .padding(.trailing, SettingsTokens.rowTrailing)
            .frame(minHeight: SettingsTokens.rowHeight)
        }
        .padding(.leading, SettingsTokens.rowLeading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .plain:
            EmptyView()
        case let .toggle(value):
            Toggle(title, isOn: value)
                .labelsHidden()
                .tint(accent)
        case let .value(value):
            Text(value)
                .font(.system(size: 17))
                .foregroundStyle(SettingsTokens.textSecondary)
        case let .valueChevron(value):
            Text(value)
                .font(.system(size: 17))
                .foregroundStyle(SettingsTokens.textSecondary)
            chevronGlyph
        case .chevron:
            chevronGlyph
        case .externalLink:
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SettingsTokens.chevron)
        }
    }

    private var chevronGlyph: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(SettingsTokens.chevron)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 13))
                .kerning(0.2)
                .foregroundStyle(SettingsTokens.textSecondary)
                .padding(.leading, SettingsTokens.rowLeading)
            content
        }
    }
}

struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(SettingsTokens.groupCard)
        .clipShape(RoundedRectangle(cornerRadius: SettingsTokens.cardRadius, style: .continuous))
    }
}

struct SettingsInsetDivider: View {
    var body: some View {
        Rectangle()
            .fill(SettingsTokens.divider)
            .frame(height: 1 / UIScreen.main.scale)
            .padding(.leading, SettingsTokens.dividerInset)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

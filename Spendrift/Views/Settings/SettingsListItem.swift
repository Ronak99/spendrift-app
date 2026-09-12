//
//  SettingsListItem.swift
//  Spendrift
//
//  Settings row styled like TransactionListItem / AccountListItem: enamel
//  chip, 16pt semibold title, optional 12pt subtitle.
//

import SwiftUI

struct SettingsListItem: View {
    enum Accessory {
        case none
        case toggle(Binding<Bool>)
        case value(String)
        case valueChevron(String)
        /// Value plus a chevron that rotates to point down while the row is open.
        case valueDisclosure(String, isExpanded: Bool)
        case chevron
        case externalLink
    }

    /// `nil` leaves the icon slot empty so the row indents under its parent.
    let icon: String?
    let title: String
    var subtitle: String?
    let accent: Color
    var accessory: Accessory = .none

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let icon {
                CategoryEnamelTile(
                    systemImage: icon,
                    color: accent,
                    showsShadow: false
                )
                .frame(width: SettingsTokens.iconSize, height: SettingsTokens.iconSize)
            } else {
                Color.clear.frame(width: SettingsTokens.iconSize, height: 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            accessoryView
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case let .toggle(value):
            Toggle(title, isOn: value)
                .labelsHidden()
                .tint(accent)
        case let .value(value):
            SettingsValueLabel(text: value)
        case let .valueChevron(value):
            HStack(spacing: 4) {
                SettingsValueLabel(text: value)
                chevronGlyph
            }
        case let .valueDisclosure(value, isExpanded):
            HStack(spacing: 4) {
                SettingsValueLabel(text: value)
                chevronGlyph
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isExpanded)
            }
        case .chevron:
            chevronGlyph
        case .externalLink:
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SettingsTokens.chevron)
        }
    }

    private var chevronGlyph: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SettingsTokens.chevron)
    }
}

#Preview {
    List {
        Section {
            SettingsListItem(
                icon: "sparkles",
                title: "Explore",
                accent: Color(hex: "#3A7BFF"),
                accessory: .chevron
            )
            .listItemPositioned(.first)

            SettingsListItem(
                icon: "bell.fill",
                title: "Daily reminder",
                subtitle: "A nudge to log spending",
                accent: Color(hex: "#3A7BFF"),
                accessory: .toggle(.constant(true))
            )
            .listItemPositioned(.last)
        }
    }
}

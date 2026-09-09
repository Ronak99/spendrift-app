//
//  SettingsListItem.swift
//  Spendrift
//
//  Settings row styled like TransactionListItem / AccountListItem.
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
    let accentSoft: Color
    var accessory: Accessory = .none

    var body: some View {
        HStack(spacing: 16) {
            if let icon {
                ZStack {
                    Circle()
                        .fill(accentSoft)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(accent)
                }
            } else {
                Color.clear.frame(width: 44, height: 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            accessoryView
        }
        .padding(.horizontal, 8)
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
                    .frame(width: 20, height: 20)
            }
        case let .valueDisclosure(value, isExpanded):
            HStack(spacing: 4) {
                SettingsValueLabel(text: value)
                chevronGlyph
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isExpanded)
            }
        case .chevron:
            chevronGlyph
        case .externalLink:
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(SettingsTokens.chevron)
        }
    }

    private var chevronGlyph: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(SettingsTokens.chevron)
    }
}

#Preview {
    List {
        Section {
            SettingsListItem(
                icon: "sparkles",
                title: "Explore",
                accent: .blue,
                accentSoft: .blue.opacity(0.16),
                accessory: .chevron
            )
            .listItemPositioned(.first)

            SettingsListItem(
                icon: "bell.fill",
                title: "Daily reminder",
                subtitle: "A nudge to log spending",
                accent: .blue,
                accentSoft: .blue.opacity(0.16),
                accessory: .toggle(.constant(true))
            )
            .listItemPositioned(.last)
        }
    }
}

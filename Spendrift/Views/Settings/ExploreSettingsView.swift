//
//  ExploreSettingsView.swift
//  Spendrift
//
//  Hub for getting money into Spendrift: the capture drill-in plus the
//  Messages automation that logs bank SMS on arrival.
//

import SwiftUI
import UIKit

struct ExploreSettingsView: View {
    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex

    private var accent: Color { Color.accentColor(forThemeIndex: selectedThemeIndex) }
    private var accentSoft: Color { accent.opacity(0.16) }

    var body: some View {
        SettingsScreen(title: "Explore") {
            Section {
                NavigationLink {
                    CaptureSettingsView()
                } label: {
                    SettingsListItem(
                        icon: "plus.circle.fill",
                        title: "Capture & shortcuts",
                        subtitle: "Speak, type, scan, import",
                        accent: accent,
                        accentSoft: accentSoft
                    )
                    .listItemPositioned(.only)
                }
            }

            automationSection
        }
        .tint(accent)
    }

    private var automationSection: some View {
        Section {
            if let shortcutURL = OnboardingShortcutShareLinks.logTransactionMessage {
                Button {
                    UIApplication.shared.open(shortcutURL)
                } label: {
                    SettingsListItem(
                        icon: "message.fill",
                        title: "Log message",
                        subtitle: "Send the latest SMS to Spendrift",
                        accent: accent,
                        accentSoft: accentSoft,
                        accessory: .chevron
                    )
                    .listItemPositioned(.only)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    BankSMSSettingsView()
                } label: {
                    SettingsListItem(
                        icon: "message.fill",
                        title: "Log message",
                        subtitle: "Send the latest SMS to Spendrift",
                        accent: accent,
                        accentSoft: accentSoft
                    )
                    .listItemPositioned(.only)
                }
            }
        } header: {
            Text("Automation")
        } footer: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Add this shortcut to a Messages automation and bank SMS get logged on arrival.")

                NavigationLink {
                    BankSMSSettingsView()
                } label: {
                    Text("See setup steps")
                        .foregroundStyle(accent)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExploreSettingsView()
    }
    .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}

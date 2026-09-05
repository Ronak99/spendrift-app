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
            SettingsCard {
                NavigationLink {
                    CaptureSettingsView()
                } label: {
                    SettingsRow(
                        icon: "plus.circle.fill",
                        title: "Capture & shortcuts",
                        subtitle: "Speak, type, scan, import",
                        accent: accent,
                        accentSoft: accentSoft
                    )
                    .content
                }
                .buttonStyle(SettingsPressStyle())
            }

            automationSection
        }
        .tint(accent)
    }

    private var automationSection: some View {
        SettingsSection(title: "Automation") {
            VStack(alignment: .leading, spacing: 8) {
                SettingsCard {
                    if let shortcutURL = OnboardingShortcutShareLinks.logTransactionMessage {
                        SettingsRow(
                            icon: "message.fill",
                            title: "Log message",
                            subtitle: "Send the latest SMS to Spendrift",
                            accent: accent,
                            accentSoft: accentSoft,
                            action: { UIApplication.shared.open(shortcutURL) }
                        )
                    } else {
                        NavigationLink {
                            BankSMSSettingsView()
                        } label: {
                            SettingsRow(
                                icon: "message.fill",
                                title: "Log message",
                                subtitle: "Send the latest SMS to Spendrift",
                                accent: accent,
                                accentSoft: accentSoft
                            )
                            .content
                        }
                        .buttonStyle(SettingsPressStyle())
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Add this shortcut to a Messages automation and bank SMS get logged on arrival.")
                        .foregroundStyle(SettingsTokens.textSecondary)

                    NavigationLink {
                        BankSMSSettingsView()
                    } label: {
                        Text("See setup steps")
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 13))
                .padding(.horizontal, SettingsTokens.rowLeading)
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

//
//  BankSMSSettingsView.swift
//  Spendrift
//
//  Drill-in for the SMS auto-logging pipeline: capture health plus the
//  Shortcuts automation the user has to build once by hand.
//

import SwiftUI

struct BankSMSSettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex

    @State private var lastCapturedAt: Date?

    private static let shortcutsAppURL = URL(string: "shortcuts://")

    private static let setupSteps: [LocalizedStringKey] = [
        "Open the Shortcuts app and go to **Automation**.",
        "Tap **+** and choose **Message**.",
        "Set **Message Contains** to “credited”.",
        "Choose **Run Immediately**, then Next.",
        "Add the action **Log Transaction Message** from Spendrift, with Message set to Shortcut Input.",
        "Repeat for “debited”.",
    ]

    private var accent: Color { Color.accentColor(forThemeIndex: selectedThemeIndex) }

    /// A capture on record is the only evidence the automation is wired up —
    /// there is no toggle to read, by design.
    private var isActive: Bool { lastCapturedAt != nil }

    static func statusLabel(lastCapturedAt: Date?) -> String {
        lastCapturedAt == nil ? "Not set up" : "Active"
    }

    private var lastCapturedLabel: String {
        guard let lastCapturedAt else { return "Never" }
        return Self.capturedFormatter.string(from: lastCapturedAt)
    }

    var body: some View {
        SettingsScreen(title: "Bank SMS", watermarkIcon: "message.fill") {
            Section {
                statusRow
                    .listItemPositioned(.first)

                SettingsListItem(
                    icon: nil,
                    title: "Last message captured",
                    accent: accent,
                    accessory: .value(lastCapturedLabel)
                )
                .listItemPositioned(.last)
            }

            Section("Set up in Shortcuts") {
                ForEach(Array(Self.setupSteps.enumerated()), id: \.offset) { index, step in
                    stepRow(number: index + 1, text: step)
                        .listItemPositioned(index: index, count: Self.setupSteps.count)
                }
            }

            Section {
                SettingsPrimaryButton(title: "Open Shortcuts") {
                    guard let url = Self.shortcutsAppURL else { return }
                    openURL(url)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listItemPositioned(.only)
            } footer: {
                VStack(spacing: 4) {
                    Text("Both automations run without opening Spendrift.")
                        .foregroundStyle(SettingsTokens.textSecondary)
                    Text("Messages are redacted on device before upload. Creating the automation is your consent to capture and parse them.")
                        .foregroundStyle(SettingsTokens.textTertiary)
                }
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { lastCapturedAt = MessageInboxSettings.lastCapturedAt }
    }

    private var statusRow: some View {
        HStack(spacing: 14) {
            CategoryEnamelTile(
                systemImage: "message.fill",
                color: isActive ? Color(hex: "#8BD17C") : Color(hex: "#8E9AA8"),
                showsShadow: false
            )
            .frame(width: SettingsTokens.iconSize, height: SettingsTokens.iconSize)

            Text(Self.statusLabel(lastCapturedAt: lastCapturedAt))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
    }

    private func stepRow(number: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#0A0A0B"))
                .frame(width: 28, height: 28)
                .background(accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
    }

    private static let capturedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationStack {
        BankSMSSettingsView()
    }
}

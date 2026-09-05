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
    private var accentSoft: Color { accent.opacity(0.16) }

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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                statusCard

                SettingsSection(title: "Set up in Shortcuts") {
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(Self.setupSteps.enumerated()), id: \.offset) { index, step in
                                stepRow(number: index + 1, text: step)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                VStack(spacing: 14) {
                    openShortcutsButton

                    VStack(spacing: 4) {
                        Text("Both automations run without opening Spendrift.")
                            .foregroundStyle(SettingsTokens.textSecondary)
                        Text("Messages are redacted on device before upload. Creating the automation is your consent to capture and parse them.")
                            .foregroundStyle(SettingsTokens.textTertiary)
                    }
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, SettingsTokens.screenInset)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(SettingsTokens.screenBackground.ignoresSafeArea())
        .navigationTitle("Bank SMS")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
        .onAppear { lastCapturedAt = MessageInboxSettings.lastCapturedAt }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isActive ? Color.green : SettingsTokens.textTertiary)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle()
                            .stroke((isActive ? Color.green : SettingsTokens.textTertiary).opacity(0.18), lineWidth: 4)
                    }

                Text(Self.statusLabel(lastCapturedAt: lastCapturedAt))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SettingsTokens.textPrimary)
            }

            Divider()
                .overlay(SettingsTokens.divider)
                .padding(.vertical, 14)

            HStack {
                Text("Last message captured")
                    .foregroundStyle(SettingsTokens.textSecondary)
                Spacer(minLength: 12)
                Text(lastCapturedLabel)
                    .foregroundStyle(SettingsTokens.textPrimary)
            }
            .font(.system(size: 15))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsTokens.groupCard)
        .clipShape(RoundedRectangle(cornerRadius: SettingsTokens.cardRadius, style: .continuous))
    }

    private func stepRow(number: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .background(accentSoft, in: Circle())

            Text(text)
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(SettingsTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private var openShortcutsButton: some View {
        Button {
            guard let url = Self.shortcutsAppURL else { return }
            openURL(url)
        } label: {
            Text("Open Shortcuts")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(accent, in: Capsule())
        }
        .buttonStyle(.plain)
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

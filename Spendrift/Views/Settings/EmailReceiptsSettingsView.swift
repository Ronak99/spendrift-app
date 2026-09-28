//
//  EmailReceiptsSettingsView.swift
//  Spendrift
//
//  Drill-in for email receipts: the personal forwarding address, a copy
//  button, and how forwarded mail turns into transactions.
//

import SwiftUI
import UIKit

struct EmailReceiptsSettingsView: View {
    @State private var lastImportedAt: Date?
    @State private var copied = false

    private static let steps: [LocalizedStringKey] = [
        "Copy your address below.",
        "Forward any receipt, order confirmation, or bank alert email to it.",
        "Open Spendrift. New emails are turned into transactions on launch.",
    ]

    private var accent: Color { AppTheme.accent }
    private var address: String { EmailInboxAddress.address }

    private var lastImportedLabel: String {
        guard let lastImportedAt else { return "Never" }
        return Self.importedFormatter.string(from: lastImportedAt)
    }

    var body: some View {
        SettingsScreen(title: "Email receipts", watermarkIcon: "envelope.fill") {
            Section {
                addressRow
                    .listItemPositioned(.first)

                SettingsListItem(
                    icon: nil,
                    title: "Last email imported",
                    accent: accent,
                    accessory: .value(lastImportedLabel)
                )
                .listItemPositioned(.last)
            } header: {
                Text("Your address")
            }

            Section("How it works") {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                    stepRow(number: index + 1, text: step)
                        .listItemPositioned(index: index, count: Self.steps.count)
                }
            }

            Section {
                SettingsPrimaryButton(
                    title: copied ? "Copied" : "Copy address",
                    systemImage: copied ? "checkmark" : "doc.on.doc"
                ) {
                    copyAddress()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listItemPositioned(.only)
            } footer: {
                VStack(spacing: 4) {
                    Text("This address is unique to this device.")
                        .foregroundStyle(SettingsTokens.textSecondary)
                    Text("Forwarded emails are stored to be parsed. Forwarding one is your consent to that.")
                        .foregroundStyle(SettingsTokens.textTertiary)
                }
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
        }
        .sensoryFeedback(.success, trigger: copied) { _, newValue in newValue }
        .onAppear { lastImportedAt = EmailInboxSettings.lastImportedAt }
    }

    private var addressRow: some View {
        HStack(spacing: 14) {
            CategoryEnamelTile(
                systemImage: "envelope.fill",
                color: accent,
                showsShadow: false
            )
            .frame(width: SettingsTokens.iconSize, height: SettingsTokens.iconSize)

            Text(address)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture { copyAddress() }
        .accessibilityLabel("Forwarding address \(address)")
        .accessibilityHint("Tap to copy")
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

    private func copyAddress() {
        UIPasteboard.general.string = address
        withAnimation(.easeInOut(duration: 0.2)) { copied = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.2)) { copied = false }
        }
    }

    private static let importedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationStack {
        EmailReceiptsSettingsView()
    }
}

//
//  MessageInboxDebugView.swift
//  Spendrift
//
//  Developer screen: inspect SMS bodies stored by Log Transaction Message.
//

import SwiftData
import SwiftUI
import UIKit

struct MessageInboxDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex

    @State private var captureLog: [MessageInboxDebugLog.Entry] = []
    @State private var pending: [MessageInboxDebugLog.PendingRow] = []
    @State private var fallback: [MessageInboxFallback.Item] = []
    @State private var pauseDrain = false
    @State private var drainStatus: String?
    @State private var isDraining = false

    private var accent: Color {
        Color.accentColor(forThemeIndex: selectedThemeIndex)
    }

    var body: some View {
        NavigationStack {
            List {
                statusSection
                captureLogSection
                pendingSection
                fallbackSection
            }
            .listStyle(.insetGrouped)
            .refreshable { reload() }
            .navigationTitle("Message inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetDismissToolbarButton()
                        .foregroundStyle(accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            Task { await syncNow() }
                        } label: {
                            if isDraining {
                                ProgressView()
                            } else {
                                Text("Sync")
                            }
                        }
                        .disabled(isDraining || !hasMessagesToSync)
                        .accessibilityLabel("Sync messages")

                        Menu {
                            Button("Refresh", systemImage: "arrow.clockwise") {
                                reload()
                            }
                            Button("Log test message", systemImage: "plus.message") {
                                Task { await logTestMessage() }
                            }
                            Divider()
                            Button("Clear capture log", systemImage: "trash", role: .destructive) {
                                MessageInboxDebugLog.clear()
                                reload()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    .foregroundStyle(accent)
                }
            }
        }
        .tint(accent)
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            reload()
        }
        .alert("Inbox sync", isPresented: Binding(
            get: { drainStatus != nil },
            set: { if !$0 { drainStatus = nil } }
        )) {
            Button("OK", role: .cancel) { drainStatus = nil }
        } message: {
            Text(drainStatus ?? "")
        }
    }

    private var pauseDrainBinding: Binding<Bool> {
        Binding(
            get: { pauseDrain },
            set: { isPaused in
                pauseDrain = isPaused
                MessageInboxDebugLog.isDrainPaused = isPaused
            }
        )
    }

    private var statusSection: some View {
        Section {
            Toggle("Pause auto-drain", isOn: pauseDrainBinding)

            LabeledContent("Last captured", value: lastCapturedLabel)
            LabeledContent("Capture log", value: "\(captureLog.count)")
            LabeledContent("Pending inbox", value: "\(pending.count)")
            LabeledContent("Fallback queue", value: "\(fallback.count)")
        } header: {
            Text("Status")
        } footer: {
            Text("Sync sends pending SwiftData SMS bodies to parse-transactions. Those rows are deleted only after HTTP 200. Pause auto-drain to inspect stored bodies. The capture log is written by the intent and is not drained.")
        }
    }

    private var captureLogSection: some View {
        Section {
            if captureLog.isEmpty {
                Text("No intent captures yet. Run the Shortcuts Message automation, then pull to refresh.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(captureLog) { entry in
                    messageRow(
                        body: entry.body,
                        capturedAt: entry.capturedAt,
                        fingerprint: entry.fingerprint,
                        badges: captureBadges(for: entry)
                    )
                }
            }
        } header: {
            Text("Capture log")
        } footer: {
            Text("Every Log Transaction Message run appends here. The first badge is whether drain wrote a row in the transactions table. The second badge is only inbox persist (saved / duplicate / fallback).")
        }
    }

    private var pendingSection: some View {
        Section {
            if pending.isEmpty {
                Text("Inbox is empty. That is expected after a successful drain.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pending) { row in
                    messageRow(
                        body: row.body,
                        capturedAt: row.capturedAt,
                        fingerprint: row.fingerprint,
                        badges: [DebugBadge(text: row.attemptCount > 0 ? "attempts \(row.attemptCount)" : "pending")]
                    )
                }
                .onDelete { offsets in
                    for index in offsets {
                        MessageInboxDebugLog.deletePending(id: pending[index].id)
                    }
                    reload()
                }
            }
        } header: {
            Text("Pending SwiftData inbox")
        } footer: {
            Text(MessageInboxDebugLog.storePathDescription)
                .font(.caption2)
                .textSelection(.enabled)
        }
    }

    private var fallbackSection: some View {
        Section {
            if fallback.isEmpty {
                Text("Fallback queue is empty.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(fallback, id: \.id) { item in
                    messageRow(
                        body: item.body,
                        capturedAt: item.capturedAt,
                        fingerprint: item.fingerprint,
                        badges: [DebugBadge(text: "fallback")]
                    )
                }
            }
        } header: {
            Text("UserDefaults fallback")
        } footer: {
            Text("Used only when the SwiftData inbox store cannot be opened from the intent.")
        }
    }

    private func messageRow(
        body: String,
        capturedAt: Date,
        fingerprint: String,
        badges: [DebugBadge]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Self.timestampFormatter.string(from: capturedAt))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(badges) { badge in
                        Text(badge.text)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundStyle(badge.emphasized ? Color.primary : Color.secondary)
                            .background(
                                (badge.emphasized ? Color.accentColor : Color.secondary)
                                    .opacity(badge.emphasized ? 0.18 : 0.14),
                                in: Capsule()
                            )
                    }
                }
            }

            Text(body)
                .font(.body)
                .textSelection(.enabled)

            Text("fp \(fingerprint.prefix(12))")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy body") {
                UIPasteboard.general.string = body
            }
        }
    }

    private var hasMessagesToSync: Bool {
        !pending.isEmpty || !fallback.isEmpty
    }

    private var lastCapturedLabel: String {
        guard let date = MessageInboxSettings.lastCapturedAt else {
            return "Never"
        }
        return Self.timestampFormatter.string(from: date)
    }

    private func captureBadges(for entry: MessageInboxDebugLog.Entry) -> [DebugBadge] {
        [
            DebugBadge(text: ledgerBadgeText(for: entry), emphasized: ledgerOutcomeIsImported(entry)),
            DebugBadge(text: persistBadgeText(entry.outcome), emphasized: false),
        ]
    }

    private func persistBadgeText(_ outcome: MessageInboxDebugLog.Outcome) -> String {
        switch outcome {
        case .inserted: "inbox saved"
        case .duplicate: "inbox duplicate"
        case .fallback: "inbox fallback"
        }
    }

    private func ledgerOutcomeIsImported(_ entry: MessageInboxDebugLog.Entry) -> Bool {
        guard let id = entry.transactionID else { return false }
        return transaction(id: id) != nil
    }

    private func ledgerBadgeText(for entry: MessageInboxDebugLog.Entry) -> String {
        if let id = entry.transactionID, let txn = transaction(id: id) {
            return "in ledger · \(txn.amount.formatCurrency)"
        }

        switch entry.ledgerOutcome {
        case .imported:
            return "imported (txn missing)"
        case .skippedDuplicate:
            return "skipped · already in ledger"
        case .rejected:
            return "not a transaction"
        case .failed:
            return "import failed"
        case nil:
            break
        }

        if pending.contains(where: { $0.fingerprint == entry.fingerprint })
            || fallback.contains(where: { $0.fingerprint == entry.fingerprint }) {
            return "pending"
        }
        return "not in ledger"
    }

    private func transaction(id: UUID) -> Transaction? {
        transactions.first { $0.isPersisted && $0.id == id }
    }

    private func reload() {
        captureLog = MessageInboxDebugLog.all()
        pending = MessageInboxDebugLog.fetchPendingInbox()
        fallback = MessageInboxFallback.peekAll()
        pauseDrain = MessageInboxDebugLog.isDrainPaused
    }

    @MainActor
    private func logTestMessage() async {
        let intent = LogTransactionMessageIntent(
            message: "INR 250.00 debited from A/c XX1234 on 24-08-26 at TEST MERCHANT. Avl Bal INR 12,345.67"
        )
        try? await intent.perform()
        reload()
    }

    @MainActor
    private func syncNow() async {
        reload()
        guard hasMessagesToSync else {
            drainStatus = "No SMS messages to sync."
            return
        }
        guard VoiceTransactionCreator.resolvePrimaryAccount(from: accounts) != nil else {
            drainStatus = "Add an account before syncing."
            return
        }
        guard (try? SpendriftBackendClient()) != nil else {
            drainStatus = "Backend is not configured."
            return
        }

        isDraining = true
        defer { isDraining = false }

        let banner = await MessageInboxSyncService.syncIfNeeded(
            ledgerContext: modelContext,
            accounts: accounts,
            categories: categories
        )
        reload()

        if let banner {
            drainStatus = "Imported \(banner.count) transaction(s)."
        } else if !pending.isEmpty {
            drainStatus = "Parse did not succeed. Inbox was not cleared."
        } else {
            drainStatus = "Messages processed. No new transactions."
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

#Preview {
    MessageInboxDebugView()
}

private struct DebugBadge: Identifiable {
    let text: String
    var emphasized: Bool = false
    var id: String { text }
}

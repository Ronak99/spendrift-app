//
//  BackupSettingsView.swift
//  Spendrift
//
//  Drill-in for backups: save a snapshot of the ledger to the server, and
//  pick an earlier one to replace everything on this device.
//

import SwiftData
import SwiftUI

struct BackupSettingsView: View {
    private enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Environment(\.modelContext) private var modelContext

    @State private var backups: [BackupSummary] = []
    @State private var loadState: LoadState = .loading
    @State private var isBackingUp = false
    @State private var restoringID: UUID?
    @State private var pendingRestore: BackupSummary?
    @State private var notice: Notice?
    @State private var successCount = 0

    private var accent: Color { AppTheme.accent }
    private var isBusy: Bool { isBackingUp || restoringID != nil }

    private var lastBackupLabel: String {
        switch loadState {
        case .loading: return "Checking"
        case .failed: return "Unknown"
        case .loaded:
            guard let latest = backups.first else { return "Never" }
            return Self.dateFormatter.string(from: latest.createdAt)
        }
    }

    var body: some View {
        SettingsScreen(title: "Backup & restore", watermarkIcon: "icloud") {
            backupSection
            restoreSection
        }
        .sensoryFeedback(.success, trigger: successCount)
        .task { await loadBackups() }
        .alert(
            "Restore this backup?",
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            presenting: pendingRestore
        ) { backup in
            Button("Replace my data", role: .destructive) {
                Task { await restore(backup) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { backup in
            Text(
                "Every transaction, account and category on this device is deleted and replaced with the backup from \(Self.dateFormatter.string(from: backup.createdAt)). Anything added since then is lost."
            )
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .cancel(Text("OK"))
            )
        }
    }

    // MARK: - Back up

    private var backupSection: some View {
        Section {
            SettingsListItem(
                icon: "clock.arrow.circlepath",
                title: "Last backup",
                accent: accent,
                accessory: .value(lastBackupLabel)
            )
            .listItemPositioned(.only)

            SettingsPrimaryButton(
                title: isBackingUp ? "Backing up" : "Back up now",
                systemImage: isBackingUp ? nil : "icloud.and.arrow.up"
            ) {
                Task { await backUp() }
            }
            .disabled(isBusy)
            .opacity(isBusy ? 0.5 : 1)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listItemPositioned(.only)
        } footer: {
            Text("Saves every account, category and transaction on this device. Backups belong to this device.")
                .font(.system(size: 13))
                .foregroundStyle(SettingsTokens.textSecondary)
        }
    }

    // MARK: - Restore

    private var restoreSection: some View {
        Section {
            switch loadState {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    statusText("Loading backups")
                }
                .padding(.horizontal, 6)
                .listItemPositioned(.only)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 10) {
                    statusText(message)
                    Button("Try again") {
                        Task { await loadBackups() }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .listItemPositioned(.only)
            case .loaded:
                if backups.isEmpty {
                    statusText("No backups yet. Back up now to create the first one.")
                        .padding(.horizontal, 6)
                        .listItemPositioned(.only)
                } else {
                    ForEach(Array(backups.enumerated()), id: \.element.id) { index, backup in
                        backupRow(backup)
                            .listItemPositioned(index: index, count: backups.count)
                    }
                }
            }
        } header: {
            Text("Restore")
        } footer: {
            if loadState == .loaded, !backups.isEmpty {
                Text("Restoring replaces everything on this device with the backup you pick. Only your most recent backups are kept.")
                    .font(.system(size: 13))
                    .foregroundStyle(SettingsTokens.textSecondary)
            }
        }
    }

    private func backupRow(_ backup: BackupSummary) -> some View {
        Button {
            pendingRestore = backup
        } label: {
            SettingsListItem(
                icon: "arrow.counterclockwise",
                title: Self.dateFormatter.string(from: backup.createdAt),
                subtitle: Self.contentsLabel(for: backup),
                accent: accent,
                accessory: restoringID == backup.id ? .progress : .chevron
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityHint("Replaces the data on this device with this backup")
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(SettingsTokens.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func loadBackups() async {
        loadState = .loading
        do {
            backups = try await BackupService.listBackups()
            loadState = .loaded
        } catch {
            loadState = .failed(Self.message(for: error))
        }
    }

    private func backUp() async {
        guard !isBusy else { return }
        isBackingUp = true
        defer { isBackingUp = false }

        do {
            _ = try await BackupService.createBackup(modelContext: modelContext)
            successCount += 1
            // The server prunes old backups on write, so reload instead of prepending.
            await loadBackups()
        } catch {
            notice = Notice(title: "Couldn't back up", message: Self.message(for: error))
        }
    }

    private func restore(_ backup: BackupSummary) async {
        guard !isBusy else { return }
        restoringID = backup.id
        defer { restoringID = nil }

        do {
            try await BackupService.restore(backup, modelContext: modelContext)
            successCount += 1
            notice = Notice(
                title: "Backup restored",
                message: "This device now matches the backup from \(Self.dateFormatter.string(from: backup.createdAt))."
            )
        } catch {
            notice = Notice(title: "Couldn't restore", message: Self.message(for: error))
        }
    }

    // MARK: - Formatting

    static func contentsLabel(for backup: BackupSummary) -> String {
        [
            counted(backup.transactionCount, one: "transaction", many: "transactions"),
            counted(backup.accountCount, one: "account", many: "accounts"),
            counted(backup.categoryCount, one: "category", many: "categories"),
        ].joined(separator: ", ")
    }

    private static func counted(_ count: Int, one: String, many: String) -> String {
        "\(count) \(count == 1 ? one : many)"
    }

    private static func message(for error: Error) -> String {
        if let backupError = error as? BackupError, let description = backupError.errorDescription {
            return description
        }
        if case let SpendriftBackendError.apiError(statusCode, _, _, _) = error {
            switch statusCode {
            case 404:
                return "That backup no longer exists."
            case 413:
                return "This backup is too large to store."
            default:
                break
            }
        }
        if let backendError = error as? SpendriftBackendError {
            switch backendError.disposition {
            case .transient:
                return "The server couldn't be reached. Check your connection and try again."
            case .rejectedPayload, .notAuthorised:
                return "Something went wrong on our side. Please try again later."
            }
        }
        if error is URLError {
            return "The server couldn't be reached. Check your connection and try again."
        }
        return "Something went wrong. Your data on this device was not changed."
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationStack {
        BackupSettingsView()
    }
    .modelContainer(
        for: [Transaction.self, Account.self, TransactionCategory.self],
        inMemory: true
    )
}

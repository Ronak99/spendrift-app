//
//  StatementImportView.swift
//  MyMoney
//
//  Created by Cursor on 06/04/26.
//

import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

struct StatementImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdOn) private var accounts: [Account]

    @State private var selectedAccount: Account?
    @State private var showFilePicker = false
    @State private var importedRows: [StatementImportRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didFinishParsing = false

    private let service = OpenAIBankStatementService()
    private static let maxPDFBytes = 20 * 1024 * 1024 // 20 MB

    var body: some View {
        NavigationStack {
            Group {
                if !didFinishParsing {
                    accountAndPickerForm
                } else {
                    previewList
                }
            }
            .navigationTitle(didFinishParsing ? "Preview Transactions" : "Import Statement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if didFinishParsing && !importedRows.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveAll() }
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Step 1: Account + PDF picker

    private var accountAndPickerForm: some View {
        Form {
            Section {
                Text("Select the bank account these transactions belong to, then pick a PDF statement.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Account") {
                if accounts.isEmpty {
                    Text("No accounts yet. Create one first.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accounts) { account in
                        Button {
                            selectedAccount = account
                        } label: {
                            HStack {
                                Text(account.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedAccount?.id == account.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    showFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("Choose PDF")
                    }
                }
                .disabled(selectedAccount == nil || isLoading)
            }

            if isLoading {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Parsing statement…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Preview

    private var previewList: some View {
        Group {
            if importedRows.isEmpty {
                ContentUnavailableView(
                    "No Transactions Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("OpenAI could not extract any transactions from this PDF.")
                )
            } else {
                List {
                    Section {
                        Text("\(importedRows.count) transactions will be added to **\(selectedAccount?.name ?? "—")**")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(importedRows) { row in
                        ImportRowView(row: row)
                    }
                    .onDelete { offsets in
                        importedRows.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - File handling + PDF validation

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                try validatePDF(data: data)
                startParsing(data: data, filename: url.lastPathComponent)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func validatePDF(data: Data) throws {
        guard data.count <= Self.maxPDFBytes else {
            throw StatementImportError.fileTooLarge
        }
        guard let doc = PDFDocument(data: data) else {
            throw StatementImportError.unreadablePDF
        }
        if doc.isEncrypted && !doc.unlock(withPassword: "") {
            throw StatementImportError.passwordProtected
        }
    }

    private func startParsing(data: Data, filename: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let rows = try await service.parseStatement(pdfData: data, filename: filename)
                await MainActor.run {
                    importedRows = rows
                    didFinishParsing = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Save

    private func saveAll() {
        guard let account = selectedAccount else { return }

        for row in importedRows {
            let transaction = Transaction(
                notes: row.notes,
                amount: row.amount,
                date: row.date,
                transactionType: row.transactionType,
                category: nil,
                account: account
            )
            modelContext.insert(transaction)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Row view

private struct ImportRowView: View {
    let row: StatementImportRow

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: row.transactionType == .expense ? "arrow.up.right" : row.transactionType == .income ? "arrow.down.left" : "questionmark")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(row.notes)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(row.date, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(row.amount.formatCurrency)
                .font(.headline)
                .foregroundStyle(row.transactionType == .expense ? .red : row.transactionType == .income ? .green : .primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Errors

enum StatementImportError: LocalizedError {
    case fileTooLarge
    case unreadablePDF
    case passwordProtected

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "This PDF exceeds the 20 MB size limit."
        case .unreadablePDF:
            return "The selected file could not be read as a PDF."
        case .passwordProtected:
            return "Password-protected PDFs are not supported yet."
        }
    }
}

#Preview {
    StatementImportView()
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}

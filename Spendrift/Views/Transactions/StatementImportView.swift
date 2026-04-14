//
//  StatementImportView.swift
//  Spendrift
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
    @State private var hasAcceptedAIDataSharing = false
    @State private var showFilePicker = false
    @State private var importedRows: [StatementImportRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didFinishParsing = false
    @State private var showPasswordSheet = false
    @State private var pendingPDFData: Data?
    @State private var pendingFilename: String?
    @State private var passwordAttempt = ""
    @State private var passwordFieldError: String?

    private let service = OpenAIBankStatementService()
    private static let maxPDFBytes = 20 * 1024 * 1024 // 20 MB

    private var selectedAccountID: Binding<UUID?> {
        Binding(
            get: { selectedAccount?.id },
            set: { newId in
                if let newId {
                    selectedAccount = accounts.first { $0.id == newId }
                } else {
                    selectedAccount = nil
                }
            }
        )
    }

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
            .sheet(isPresented: $showPasswordSheet, onDismiss: {
                passwordAttempt = ""
                passwordFieldError = nil
                if !isLoading {
                    pendingPDFData = nil
                    pendingFilename = nil
                }
            }) {
                pdfPasswordSheet
            }
            .onAppear {
                guard selectedAccount == nil, let primary = accounts.first(where: { $0.isPrimary }) else { return }
                selectedAccount = primary
            }
        }
    }

    private func accountPickerLabel(_ account: Account) -> String {
        account.isPrimary ? "\(account.name) (Primary)" : account.name
    }

    // MARK: - Step 1: Account + PDF picker

    private var accountAndPickerForm: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy notice")
                            .font(.subheadline.weight(.semibold))
                        Text(
                            "Bank statements can include sensitive details such as account information, balances, and who you paid or received money from. "
                            + "The PDF you select is sent to a third-party AI service so it can read the document and suggest transactions. "
                            + "Only use this import if you are comfortable with that data leaving your device and being processed by the AI provider."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle(isOn: $hasAcceptedAIDataSharing) {
                    Text("I understand and want to continue")
                        .font(.subheadline)
                }
                .accessibilityHint("Required before you can upload a statement PDF.")
            } footer: {
                Text("You must turn this on to choose a PDF.")
                    .font(.caption)
            }

            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose which account this statement belongs to. Imported rows will be saved there after you pick a PDF.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if accounts.isEmpty {
                        Text("No accounts yet. Add one from the Accounts tab, then return here.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    } else {
                        Picker("Account", selection: selectedAccountID) {
                            Text("Select account").tag(nil as UUID?)
                            ForEach(accounts) { account in
                                Text(accountPickerLabel(account)).tag(Optional(account.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(.vertical, 2)
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
                .disabled(!hasAcceptedAIDataSharing || selectedAccount == nil || isLoading)
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

    // MARK: - Password sheet (encrypted PDFs)

    private var pdfPasswordSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This PDF is password-protected. Enter the document password so it can be unlocked on your device before anything is sent for parsing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    SecureField("PDF password", text: $passwordAttempt)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    if let passwordFieldError {
                        Text(passwordFieldError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Unlock PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPasswordSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        tryUnlockPendingPDF()
                    }
                    .disabled(passwordAttempt.isEmpty || isLoading)
                }
            }
        }
        .presentationDetents([.medium])
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
                try validatePDFBasics(data: data)
                guard let doc = PDFDocument(data: data) else {
                    throw StatementImportError.unreadablePDF
                }
                if doc.isEncrypted && !doc.unlock(withPassword: "") {
                    pendingPDFData = data
                    pendingFilename = url.lastPathComponent
                    passwordFieldError = nil
                    showPasswordSheet = true
                    return
                }
                startParsing(data: data, filename: url.lastPathComponent)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func validatePDFBasics(data: Data) throws {
        guard data.count <= Self.maxPDFBytes else {
            throw StatementImportError.fileTooLarge
        }
    }

    private func tryUnlockPendingPDF() {
        guard let data = pendingPDFData, let filename = pendingFilename else {
            showPasswordSheet = false
            return
        }
        passwordFieldError = nil

        guard let doc = PDFDocument(data: data) else {
            passwordFieldError = StatementImportError.unreadablePDF.localizedDescription
            return
        }
        guard doc.isEncrypted else {
            showPasswordSheet = false
            startParsing(data: data, filename: filename)
            return
        }
        guard doc.unlock(withPassword: passwordAttempt) else {
            passwordFieldError = StatementImportError.incorrectPDFPassword.localizedDescription
            return
        }

        do {
            let decrypted = try decryptedPDFData(from: doc)
            try validatePDFBasics(data: decrypted)
            passwordAttempt = ""
            showPasswordSheet = false
            pendingPDFData = nil
            pendingFilename = nil
            startParsing(data: decrypted, filename: filename)
        } catch {
            passwordFieldError = error.localizedDescription
        }
    }

    /// Writes the unlocked document to a temporary file and reads it back so we send decrypted bytes to the API.
    private func decryptedPDFData(from document: PDFDocument) throws -> Data {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        guard document.write(to: tempURL) else {
            throw StatementImportError.couldNotExportUnlockedPDF
        }
        return try Data(contentsOf: tempURL)
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
        do {
            try modelContext.save()
            AppStoreReviewRequest.requestIfFirstTime(forKey: AppStoreReviewRequest.Keys.firstStatementImport)
            dismiss()
        } catch {
            errorMessage = "Could not save transactions. \(error.localizedDescription)"
        }
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
    case incorrectPDFPassword
    case couldNotExportUnlockedPDF

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "This PDF exceeds the 20 MB size limit."
        case .unreadablePDF:
            return "The selected file could not be read as a PDF."
        case .incorrectPDFPassword:
            return "That password did not unlock this PDF. Check caps lock and try again."
        case .couldNotExportUnlockedPDF:
            return "The PDF unlocked, but it could not be prepared for upload. Try saving a copy without a password in Files and import that file."
        }
    }
}

#Preview {
    StatementImportView()
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}

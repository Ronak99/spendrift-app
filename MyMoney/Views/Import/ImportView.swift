//
//  ImportView.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ImportViewModel()
    @State private var showDocumentPicker = false
    @State private var showPrivacySheet = false
    @State private var showViewImports = false
    @State private var documentPickerType: DocumentPickerType = .pdf
    @State private var lastPickedURL: URL?
    
    enum DocumentPickerType {
        case pdf
        case csv
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Privacy Info Card
                    if viewModel.showPrivacyInfo {
                        PrivacyInfoCard(
                            onLearnMore: { showPrivacySheet = true },
                            onDismiss: { viewModel.showPrivacyInfo = false }
                        )
                        .padding(.horizontal)
                    }
                    
                    // Bank Statement Import Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statement")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("We have added PDF parsers for bank statements for select banks.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Picker("Bank", selection: $viewModel.selectedBank) {
                            ForEach(ImportViewModel.BankType.allCases, id: \.self) { bank in
                                Text(bank.rawValue).tag(bank)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Button(action: {
                            documentPickerType = .pdf
                            showDocumentPicker = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("Import PDF Statement")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // CSV Import Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Existing Records")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Import CSV from your existing finance management apps.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Picker("App", selection: $viewModel.selectedApp) {
                            ForEach(ImportViewModel.CSVAppType.allCases, id: \.self) { app in
                                Text(app.rawValue).tag(app)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Button(action: {
                            documentPickerType = .csv
                            showDocumentPicker = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import CSV")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // View Imports Button
                    if !viewModel.importedTransactions.isEmpty {
                        Button(action: { showViewImports = true }) {
                            HStack {
                                Image(systemName: "eye")
                                Text("View Imports (\(viewModel.importedTransactions.count))")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Import")
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(
                    allowedContentTypes: documentPickerType == .pdf ? [.pdf] : [.commaSeparatedText],
                    onDocumentPicked: { url in
                        lastPickedURL = url
                        handleDocumentImport(url: url, type: documentPickerType)
                    }
                )
            }
            .sheet(isPresented: $showPrivacySheet) {
                PrivacySheet()
            }
            .sheet(isPresented: $showViewImports) {
                ViewImportsView(
                    importedTransactions: $viewModel.importedTransactions,
                    onSave: {
                        saveImportedTransactions()
                    }
                )
            }
            .alert("Password Required", isPresented: $viewModel.showPasswordAlert) {
                SecureField("Enter PDF password", text: $viewModel.passwordInput)
                Button("Unlock") {
                    if let url = getLastPickedURL() {
                        handleDocumentImport(url: url, type: .pdf)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.showPasswordAlert = false
                    viewModel.passwordInput = ""
                }
            } message: {
                Text("This PDF is password protected.")
            }
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private func handleDocumentImport(url: URL, type: DocumentPickerType) {
        viewModel.isLoading = true
        
        Task {
            do {
                if type == .pdf {
                    try await importPDF(url: url)
                } else {
                    try await importCSV(url: url)
                }
            } catch {
                if let pdfError = error as? PDFParserError, pdfError == .passwordRequired {
                    viewModel.showPasswordAlert = true
                } else {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showErrorAlert = true
                }
            }
            
            viewModel.isLoading = false
        }
    }
    
    private func importPDF(url: URL) async throws {
        let parserService = PDFParserService()
        
        // Check if password is needed
        if let pdfDocument = PDFDocument(url: url), pdfDocument.isEncrypted {
            if viewModel.passwordInput.isEmpty {
                throw PDFParserError.passwordRequired
            }
        }
        
        let transactions = try await parserService.parsePDF(
            from: url,
            bank: viewModel.selectedBank,
            password: viewModel.passwordInput.isEmpty ? nil : viewModel.passwordInput
        )
        
        // Check for duplicates
        let existingKeys = Set(getExistingTransactionKeys())
        let newTransactions = transactions.filter { transaction in
            let key = "\(transaction.date.year)_\(transaction.date.month)_\(transaction.date.day)_\(transaction.amount)_\(transaction.transactionType.rawValue)"
            return !existingKeys.contains(key)
        }
        
        viewModel.importedTransactions.append(contentsOf: newTransactions)
        viewModel.passwordInput = ""
    }
    
    private func importCSV(url: URL) async throws {
        let parserService = CSVParserService()
        let transactions = try await parserService.parseCSV(from: url, app: viewModel.selectedApp)
        
        // Check for duplicates
        let existingKeys = Set(getExistingTransactionKeys())
        let newTransactions = transactions.filter { transaction in
            let key = "\(transaction.date.year)_\(transaction.date.month)_\(transaction.date.day)_\(transaction.amount)_\(transaction.transactionType.rawValue)"
            return !existingKeys.contains(key)
        }
        
        viewModel.importedTransactions.append(contentsOf: newTransactions)
    }
    
    private func getExistingTransactionKeys() -> [String] {
        let descriptor = FetchDescriptor<Transaction>()
        guard let existingTransactions = try? modelContext.fetch(descriptor) else {
            return []
        }
        return existingTransactions.map { $0.keyValues }
    }
    
    private func getLastPickedURL() -> URL? {
        return lastPickedURL
    }
    
    private func saveImportedTransactions() {
        // Save imported transactions to SwiftData
        for imported in viewModel.importedTransactions {
            let transaction = Transaction(
                notes: imported.notes,
                amount: imported.amount,
                date: imported.date,
                transactionType: imported.transactionType,
                category: imported.category,
                account: imported.account
            )
            modelContext.insert(transaction)
        }
        
        try? modelContext.save()
        viewModel.importedTransactions = []
    }
}

struct PrivacyInfoCard: View {
    let onLearnMore: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Privacy Built-In!")
                    .font(.headline)
            }
            
            Text("This app keeps all your data on your device, nothing is stored in the cloud.")
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Learn More", action: onLearnMore)
                    .font(.subheadline)
                
                Spacer()
                
                Button("Dismiss", action: onDismiss)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("My Money is designed with your privacy in mind. All your financial data is stored locally on your device using SwiftData. We do not collect, transmit, or store any of your information on external servers.")
                        .font(.body)
                    
                    Text("Key Privacy Features:")
                        .font(.headline)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Local-only storage", systemImage: "checkmark.circle.fill")
                        Label("No cloud sync", systemImage: "checkmark.circle.fill")
                        Label("No data collection", systemImage: "checkmark.circle.fill")
                        Label("No analytics tracking", systemImage: "checkmark.circle.fill")
                    }
                    .font(.body)
                }
                .padding()
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ImportView()
        .modelContainer(for: [Transaction.self], inMemory: true)
}

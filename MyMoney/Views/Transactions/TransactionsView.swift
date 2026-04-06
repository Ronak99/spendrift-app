//
//  TransactionsView.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    @State private var viewModel = TransactionViewModel()
    @State private var showCreateSheet = false
    @State private var showStatementImport = false
    @State private var voiceInline = VoiceInlineCaptureController()
    @State private var selectedTransaction: Transaction?
    let voiceCaptureTrigger: UUID?
    let useCompactVoiceCapture: Bool
    let shortcutImportedAudio: ShortcutImportedAudioPayload?

    init(
        voiceCaptureTrigger: UUID? = nil,
        useCompactVoiceCapture: Bool = false,
        shortcutImportedAudio: ShortcutImportedAudioPayload? = nil
    ) {
        self.voiceCaptureTrigger = voiceCaptureTrigger
        self.useCompactVoiceCapture = useCompactVoiceCapture
        self.shortcutImportedAudio = shortcutImportedAudio
    }
    
    private var transactions: [Transaction] {
        allTransactions.filter { transaction in
            transaction.date >= viewModel.startOfMonth && transaction.date <= viewModel.endOfMonth
        }
    }
    
    
    private var totalExpenses: Double {
        transactions.totalExpenses
    }
    
    private var totalIncome: Double {
        transactions.totalIncome
    }
    
    private var savings: Double {
        transactions.savings
    }
    
    var body: some View {
        @Bindable var voice = voiceInline
        NavigationStack {
            VStack(spacing: 0) {
                // Header with date selector
                VStack(spacing: 16) {
                    CapsuleDateSelector(
                        date: viewModel.selectedDate,
                        onPrevious: { viewModel.decrementMonth() },
                        onNext: { viewModel.incrementMonth() }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Statistics bar
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expenses")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(totalExpenses.formatCurrency)
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Income")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(totalIncome.formatCurrency)
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Savings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(savings.formatCurrency)
                                .font(.headline)
                                .foregroundColor(savings >= 0 ? .green : .red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
                
                // Transaction list
                if transactions.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "No Transactions",
                        description: "Get started by adding your first transaction for \(viewModel.selectedDate.monthYear)",
                        actionTitle: "Add Transaction",
                        action: { showCreateSheet = true }
                    )
                } else {
                    List {
                        ForEach(transactions.groupedByDateRecentFirst, id: \.dayStart) { section in
                            Section {
                                ForEach(section.transactions, id: \.id) { transaction in
                                    TransactionListItem(transaction: transaction)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedTransaction = transaction
                                        }
                                }
                                .onDelete { indexSet in
                                    deleteTransactions(at: indexSet, in: section.transactions)
                                }
                            } header: {
                                Text(section.title)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Button {
                                voiceInline.beginCapture()
                            } label: {
                                Label("Speak", systemImage: "mic")
                            }
                            .disabled(voiceInline.blocksNewCapture)

                            Button {
                                showCreateSheet = true
                            } label: {
                                Label("Type", systemImage: "keyboard")
                            }

                            Button {
                                showStatementImport = true
                            } label: {
                                Label("Upload document", systemImage: "doc.text")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add transaction")
                        .accessibilityIdentifier("transactionsAddMenu")

                        ProfileSettingsToolbarButton()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if true {
                    VoiceInlineRecordingBar(
                        controller: voiceInline,
                        accounts: accounts,
                        categories: categories
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: voiceInline.displayState)
            .sheet(isPresented: $showStatementImport) {
                StatementImportView()
            }
            .sheet(isPresented: $showCreateSheet) {
                UpdateTransactionSheet(transaction: nil)
            }
            .sheet(item: $selectedTransaction) { transaction in
                UpdateTransactionSheet(transaction: transaction)
            }
            .sheet(item: $voice.manualSheetPayload) { payload in
                UpdateTransactionSheet(
                    transaction: nil,
                    draft: payload.draft,
                    voiceReviewHint: payload.hint
                )
            }
            .onChange(of: voiceCaptureTrigger) { _, trigger in
                guard trigger != nil else { return }
                showCreateSheet = false
                voiceInline.beginCapture()
            }
            .task(id: shortcutImportedAudio?.id) {
                guard let payload = shortcutImportedAudio else { return }
                showCreateSheet = false
                voiceInline.processImportedAudio(
                    fileURL: payload.fileURL,
                    modelContext: modelContext,
                    accounts: accounts,
                    categories: categories
                )
            }
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet, in transactionsForDay: [Transaction]) {
        for index in offsets {
            modelContext.delete(transactionsForDay[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    TransactionsView()
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}

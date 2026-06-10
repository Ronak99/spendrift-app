//
//  TransactionsView.swift
//  Spendrift
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
    var periodViewModel: TransactionViewModel
    @State private var showCreateSheet = false
    @State private var showStatementImport = false
    @State private var voiceInline = VoiceInlineCaptureController()
    @State private var selectedTransaction: Transaction?
    @State private var lastHandledVoiceCaptureTrigger: UUID?
    let voiceCaptureTrigger: UUID?
    let useCompactVoiceCapture: Bool
    let shortcutImportedAudio: ShortcutImportedAudioPayload?

    init(
        periodViewModel: TransactionViewModel,
        voiceCaptureTrigger: UUID? = nil,
        useCompactVoiceCapture: Bool = false,
        shortcutImportedAudio: ShortcutImportedAudioPayload? = nil
    ) {
        self.periodViewModel = periodViewModel
        self.voiceCaptureTrigger = voiceCaptureTrigger
        self.useCompactVoiceCapture = useCompactVoiceCapture
        self.shortcutImportedAudio = shortcutImportedAudio
    }
    
    private var transactions: [Transaction] {
        allTransactions.filter { transaction in
            transaction.date >= periodViewModel.periodStart && transaction.date <= periodViewModel.periodEnd
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

    /// Round summary figures when there are many transactions — decimal precision
    /// adds noise rather than clarity at that scale.
    private var usesRoundedSummary: Bool {
        transactions.count > 10
    }

    private var formattedExpenses: String {
        usesRoundedSummary ? totalExpenses.formatCurrencyRounded : totalExpenses.formatCurrency
    }

    private var formattedIncome: String {
        usesRoundedSummary ? totalIncome.formatCurrencyRounded : totalIncome.formatCurrency
    }

    private var formattedSavings: String {
        usesRoundedSummary ? savings.formatCurrencyRounded : savings.formatCurrency
    }

    private var categoriesSortedByLastUsed: [TransactionCategory] {
        categories.sortedByLastUsage()
    }

    var body: some View {
        @Bindable var voice = voiceInline
        @Bindable var periodViewModel = periodViewModel
        NavigationStack {
            VStack(spacing: 0) {
                // Header with date selector
                VStack(spacing: 16) {
                    CapsuleDateSelector(
                        period: periodViewModel.periodGranularity,
                        title: periodViewModel.capsuleTitle,
                        date: periodViewModel.selectedDate,
                        isCurrentPeriod: periodViewModel.isCurrentPeriod,
                        onPrevious: { periodViewModel.decrementPeriod() },
                        onNext: { periodViewModel.incrementPeriod() },
                        onToday: { periodViewModel.goToCurrentPeriod() },
                        onJumpToDate: { periodViewModel.goToDate($0) }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Statistics bar
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expenses")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedExpenses)
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Income")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedIncome)
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Savings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedSavings)
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
                        description: "Get started by adding your first transaction for \(periodViewModel.periodDescription)",
                        actionTitle: "Add Transaction",
                        action: nil,
                        addTransactionMenu: EmptyStateAddTransactionMenu(
                            onSpeak: { voiceInline.beginCapture() },
                            onType: { showCreateSheet = true },
                            onUploadDocument: { showStatementImport = true },
                            voiceDisabled: voiceInline.blocksNewCapture
                        )
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
                if !transactions.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        TransactionPeriodToolbarMenu(period: $periodViewModel.periodGranularity)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        if !transactions.isEmpty {
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
                        }

                        ProfileSettingsToolbarButton()
                    }
                    .padding(.horizontal, transactions.isEmpty ? 0 : 8)
                }
            }
            .overlay(alignment: .bottom) {
                if true {
                    VoiceInlineRecordingBar(
                        controller: voiceInline,
                        accounts: accounts,
                        categories: categoriesSortedByLastUsed
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
                handleVoiceCaptureTrigger(trigger)
            }
            .onAppear {
                handleVoiceCaptureTrigger(voiceCaptureTrigger)
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

    private func handleVoiceCaptureTrigger(_ trigger: UUID?) {
        guard let trigger, trigger != lastHandledVoiceCaptureTrigger else { return }
        lastHandledVoiceCaptureTrigger = trigger
        showCreateSheet = false
        Task {
            if useCompactVoiceCapture {
                // Siri / Shortcuts can hand off before the mic is available.
                try? await Task.sleep(for: .milliseconds(400))
            }
            guard !Task.isCancelled else { return }
            voiceInline.beginCapture()
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
    TransactionsView(periodViewModel: TransactionViewModel())
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}

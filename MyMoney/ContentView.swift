//
//  ContentView.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Combine
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    @AppStorage("themeColor") private var themeColorName: String = "Blue"
    @State private var selectedTab = 0
    @State private var showCreateTransaction = false
    @State private var voiceCaptureTrigger: UUID?
    @State private var shortcutImportedAudio: ShortcutImportedAudioPayload?
    @State private var useCompactVoiceCapture = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TransactionsView(
                voiceCaptureTrigger: voiceCaptureTrigger,
                useCompactVoiceCapture: useCompactVoiceCapture,
                shortcutImportedAudio: shortcutImportedAudio
            )
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Transactions")
                }
                .tag(0)
            AccountsView()
                .tabItem {
                    Image(systemName: "creditcard")
                    Text("Accounts")
                }
                .tag(1)
            
            CategoriesView()
                .tabItem {
                    Image(systemName: "folder")
                    Text("Categories")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(3)
        }
        .tint(Color.themeColors[themeColorName] ?? .blue)
        .onAppear {
            QuickActionsManager.setupQuickActions()
            seedDefaultCategoriesIfNeeded()
            handleVoiceIntentLaunchIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            handleVoiceIntentLaunchIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceExpenseIntentTriggered)) { _ in
            handleVoiceIntentLaunchIfNeeded()
        }
        .onOpenURL { url in
            handleQuickAction(url: url)
        }
        .sheet(isPresented: $showCreateTransaction) {
            UpdateTransactionSheet(transaction: nil)
        }
    }
    
    private func handleQuickAction(url: URL) {
        guard url.scheme == "mymoney" else { return }
        
        switch url.host {
        case "createTransaction":
            showCreateTransaction = true
            selectedTab = 0
            useCompactVoiceCapture = false
        case "voiceExpense":
            showCreateTransaction = false
            selectedTab = 0
            useCompactVoiceCapture = true
            voiceCaptureTrigger = UUID()
        default:
            useCompactVoiceCapture = false
            break
        }
    }

    private func handleVoiceIntentLaunchIfNeeded() {
        let defaults = UserDefaults.standard

        if let path = defaults.string(forKey: VoiceExpenseIntent.pendingImportPathKey), !path.isEmpty {
            defaults.removeObject(forKey: VoiceExpenseIntent.pendingImportPathKey)
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return }
            showCreateTransaction = false
            selectedTab = 0
            useCompactVoiceCapture = true
            shortcutImportedAudio = ShortcutImportedAudioPayload(id: UUID(), fileURL: url)
            return
        }

        guard defaults.object(forKey: VoiceExpenseIntent.launchTriggerKey) != nil else {
            return
        }

        defaults.removeObject(forKey: VoiceExpenseIntent.launchTriggerKey)
        showCreateTransaction = false
        selectedTab = 0
        useCompactVoiceCapture = true
        voiceCaptureTrigger = UUID()
    }

    private func seedDefaultCategoriesIfNeeded() {
        guard categories.isEmpty else { return }
        let defaults = TransactionCategory.defaultCategories()
        for category in defaults {
            modelContext.insert(category)
        }
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}

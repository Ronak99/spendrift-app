//
//  MyMoneyApp.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData
import AppIntents

// Add a run argument : -com.apple.CoreData.SQLDebug 1 to visualize the SQLite data

@main
struct MyMoneyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let sharedContainer: ModelContainer

    init() {
        // Ensure Shortcuts picks up newly added/changed intent parameters.
        Task {
            try? await ExpenseAppShortcuts.updateAppShortcutParameters()
        }

        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")
        if let container = try? IntentSwiftData.makeModelContainer() {
            sharedContainer = container
        } else {
            // Last-resort fallback — should never be reached in production.
            let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
            sharedContainer = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: isUITesting)]
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootContainerView()
        }
        .modelContainer(sharedContainer)
    }
}

private struct RootContainerView: View {
    /// Stores the onboarding version the user has completed.
    /// 0 = never shown. Bump `OnboardingCarouselView.currentVersion` in code to re-show on major updates.
    @AppStorage("mymoneyOnboardingVersion") private var onboardingVersion = 0

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }

    private var showOnboarding: Bool {
       onboardingVersion < OnboardingCarouselView.currentVersion && !isUITesting
    }

    var body: some View {
        ContentView()
            .sheet(isPresented: .constant(showOnboarding)) {
                OnboardingCarouselView(onboardingVersion: $onboardingVersion)
                    .interactiveDismissDisabled(true)
            }
    }
}

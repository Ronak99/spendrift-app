//
//  SpendriftApp.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData
import AppIntents

// Add a run argument : -com.apple.CoreData.SQLDebug 1 to visualize the SQLite data

@main
struct SpendriftApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let sharedContainer: ModelContainer

    init() {
        Analytics.bootstrap()
        Diagnostics.bootstrap()

        // Ensure Shortcuts picks up newly added/changed intent parameters.
        Task {
            ExpenseAppShortcuts.updateAppShortcutParameters()
        }

        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")
        if let container = try? IntentSwiftData.makeModelContainer() {
            sharedContainer = container
            #if DEBUG
            DebugSwiftBootstrap.rememberStores(
                ledger: container,
                inbox: try? MessageInboxSwiftData.makeModelContainer()
            )
            #endif
        } else {
            // Last-resort fallback — should never be reached in production.
            Diagnostics.log(
                "ModelContainer bootstrap fell back to in-memory store",
                level: .error,
                tags: [
                    Diagnostics.Tag.feature: Diagnostics.Feature.app.rawValue,
                    Diagnostics.Tag.stage: Diagnostics.Stage.bootstrap.rawValue
                ]
            )
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

// MARK: - Root sheet priority queue

/// All sheets that RootContainerView can display, ordered by priority (highest first).
private enum RootSheet: Identifiable, Equatable {
    case mandatoryUpdate(version: String?, storeURL: URL?)
    case onboarding
    case optionalUpdate(version: String?, storeURL: URL?)

    var id: String {
        switch self {
        case .mandatoryUpdate: "mandatoryUpdate"
        case .onboarding:      "onboarding"
        case .optionalUpdate:  "optionalUpdate"
        }
    }
}

// MARK: - Root container

private struct RootContainerView: View {
    @Environment(\.modelContext) private var modelContext

    /// Stores the onboarding version the user has completed.
    /// 0 = never shown. Bump `OnboardingCarouselView.currentVersion` in code to re-show on major updates.
    @AppStorage("spendriftOnboardingVersion") private var onboardingVersion = 0

    @State private var checker = AppUpdateChecker()
    @State private var activeSheet: RootSheet?
    /// Guards against starting the background seed more than once per launch.
    @State private var didStartSeeding = false

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }

    private var needsOnboarding: Bool {
        onboardingVersion < OnboardingCarouselView.currentVersion && !isUITesting
    }

    var body: some View {
        ContentView()
            .task {
                await checker.check()
                resolveActiveSheet()
            }
            // Completing onboarding updates `onboardingVersion` only; `activeSheet` must be cleared here
            // or the sheet never dismisses (onDisappear never runs while `.onboarding` stays set).
            .onChange(of: onboardingVersion) { _, _ in
                resolveActiveSheet()
            }
            // Seeding is unified here: the moment onboarding starts we seed the default
            // account and categories if the local store is empty.
            .onChange(of: activeSheet) { _, sheet in
                guard case .onboarding = sheet, !didStartSeeding else { return }
                didStartSeeding = true
                DefaultDataSeeder.seedIfNeeded(modelContext: modelContext)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .mandatoryUpdate(let version, let url):
                    AppUpdateSheet(kind: .mandatory, latestVersion: version, storeURL: url)
                        .interactiveDismissDisabled(true)

                case .onboarding:
                    OnboardingCarouselView(onboardingVersion: $onboardingVersion)
                        .interactiveDismissDisabled(true)
                        .onDisappear { resolveActiveSheet() }

                case .optionalUpdate(let version, let url):
                    AppUpdateSheet(kind: .optional, latestVersion: version, storeURL: url)
                }
            }
    }

    /// Determines which sheet to surface based on priority:
    /// mandatory update > onboarding > optional update.
    private func resolveActiveSheet() {
        if case .mandatoryUpdate = activeSheet { return }

        if checker.updateKind == .mandatory {
            activeSheet = .mandatoryUpdate(
                version: checker.latestVersion,
                storeURL: checker.storeURL
            )
        } else if needsOnboarding {
            activeSheet = .onboarding
        } else if checker.updateKind == .optional {
            activeSheet = .optionalUpdate(
                version: checker.latestVersion,
                storeURL: checker.storeURL
            )
        } else {
            activeSheet = nil
        }
    }
}

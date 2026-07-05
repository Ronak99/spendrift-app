//
//  CategoryCatalogService.swift
//  Spendrift
//

import Foundation
import SwiftData

enum CategoryCatalogService {
    enum OnboardingChoice {
        case keepSuggested
        case startFresh
        case skip
    }

    /// Deletes unused bundled defaults, then inserts the minimal core if needed.
    static func applyStartFresh(modelContext: ModelContext, source: CategoryEventSource) throws {
        let removed = try deleteUnusedDefaults(modelContext: modelContext, source: source)
        try seedMinimalCoreIfNeeded(modelContext: modelContext)
        captureConfigured(method: "start_fresh", removedCount: removed, keptCount: countDefaults(in: modelContext))
        try modelContext.save()
    }

    /// Removes bundled defaults that have no linked transactions.
    @discardableResult
    static func deleteUnusedDefaults(modelContext: ModelContext, source: CategoryEventSource) throws -> Int {
        let categories = try modelContext.fetch(FetchDescriptor<TransactionCategory>())
        var removed = 0

        for category in categories where category.isDefault {
            let hasTransactions = !(category.transactions?.isEmpty ?? true)
            guard !hasTransactions else { continue }
            Analytics.capture(.categoryDeleted, [
                Analytics.Key.name: category.name,
                Analytics.Key.isDefault: true,
                Analytics.Key.source: source.rawValue
            ])
            modelContext.delete(category)
            removed += 1
        }

        return removed
    }

    /// Replaces unused legacy defaults with the curated universal core.
    static func resetToSuggestedCategories(modelContext: ModelContext, source: CategoryEventSource) throws {
        let removed = try deleteUnusedDefaults(modelContext: modelContext, source: source)
        let existing = try modelContext.fetch(FetchDescriptor<TransactionCategory>())
        let existingSignatures = Set(existing.map(\.catalogSignature))

        for template in TransactionCategory.defaultCategories() {
            guard !existingSignatures.contains(template.catalogSignature) else { continue }
            modelContext.insert(template)
        }

        captureConfigured(method: "suggested", removedCount: removed, keptCount: countDefaults(in: modelContext))
        try modelContext.save()
    }

    static func applyOnboardingChoice(_ choice: OnboardingChoice, modelContext: ModelContext) {
        switch choice {
        case .keepSuggested:
            captureConfigured(method: "suggested", removedCount: 0, keptCount: countDefaults(in: modelContext))
        case .startFresh:
            try? applyStartFresh(modelContext: modelContext, source: .onboarding)
        case .skip:
            captureConfigured(method: "skipped", removedCount: 0, keptCount: countDefaults(in: modelContext))
        }
    }

    private static func seedMinimalCoreIfNeeded(modelContext: ModelContext) throws {
        let existing = try modelContext.fetch(FetchDescriptor<TransactionCategory>())
        let signatures = Set(existing.map(\.catalogSignature))

        for template in TransactionCategory.minimalCore() {
            guard !signatures.contains(template.catalogSignature) else { continue }
            modelContext.insert(template)
        }
    }

    private static func countDefaults(in modelContext: ModelContext) -> Int {
        let categories = (try? modelContext.fetch(FetchDescriptor<TransactionCategory>())) ?? []
        return categories.filter(\.isDefault).count
    }

    private static func captureConfigured(method: String, removedCount: Int, keptCount: Int) {
        Analytics.capture(.categoriesConfigured, [
            Analytics.Key.method: method,
            Analytics.Key.removedCount: removedCount,
            Analytics.Key.keptCount: keptCount
        ])
    }
}

//
//  ExpenseCategoryAppEntity.swift
//  Spendrift
//
//  Created by Cursor on 30/03/26.
//

import AppIntents
import SwiftData

struct ExpenseCategoryEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Expense Category"
    static var defaultQuery = ExpenseCategoryQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(model: TransactionCategory) {
        self.id = model.id.uuidString
        self.name = model.name
    }
}

struct ExpenseCategoryQuery: EnumerableEntityQuery {
    func allEntities() async throws -> [ExpenseCategoryEntity] {
        let container = try IntentSwiftData.makeModelContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TransactionCategory>(sortBy: [SortDescriptor(\.name)])
        let models = try context.fetch(descriptor).sortedByLastUsage()
        return models.map { ExpenseCategoryEntity(model: $0) }
    }

    func entities(for identifiers: [ExpenseCategoryEntity.ID]) async throws -> [ExpenseCategoryEntity] {
        let uuidSet = Set(identifiers.compactMap { UUID(uuidString: $0) })
        guard !uuidSet.isEmpty else { return [] }
        let container = try IntentSwiftData.makeModelContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TransactionCategory>(sortBy: [SortDescriptor(\.name)])
        let models = try context.fetch(descriptor)
        return models
            .filter { uuidSet.contains($0.id) }
            .map { ExpenseCategoryEntity(model: $0) }
    }
}

//
//  SearchRecents.swift
//  Spendrift
//
//  The last five searches, kept on the device. Saved when a query is submitted or
//  one of its results is opened, never on every keystroke.
//

import Foundation
import Observation

@MainActor
@Observable
final class SearchRecents {
    static let shared = SearchRecents()

    private static let key = "spendrift.search.recent"
    private static let limit = 5

    private(set) var queries: [String]

    private init() {
        queries = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func remember(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = queries.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        updated.insert(trimmed, at: 0)
        queries = Array(updated.prefix(Self.limit))
        persist()
    }

    func remove(_ query: String) {
        queries.removeAll { $0 == query }
        persist()
    }

    func clear() {
        queries = []
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(queries, forKey: Self.key)
    }
}

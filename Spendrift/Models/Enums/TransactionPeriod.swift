//
//  TransactionPeriod.swift
//  Spendrift
//

import Foundation

/// How transactions and analytics are scoped in time. Persisted app-wide via `TransactionViewModel`.
enum TransactionPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case threeMonths
    case sixMonths
    case year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

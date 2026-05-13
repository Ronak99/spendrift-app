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
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .year: return "Year"
        }
    }

    /// Number of calendar months in a rolling window that **ends** in the anchor month (`selectedDate`), including that month.
    var inclusiveRollingMonthCount: Int? {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .week, .month, .year: return nil
        }
    }
}

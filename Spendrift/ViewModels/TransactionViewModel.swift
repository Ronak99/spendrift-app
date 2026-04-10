//
//  TransactionViewModel.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftUI

private let transactionPeriodGranularityKey = "transactionPeriodGranularity"
private let transactionPeriodSelectedDateKey = "transactionPeriodSelectedDate"

@Observable
class TransactionViewModel {
    /// Anchor date for the visible week / month / year; persisted so tabs and drill-downs stay aligned.
    var selectedDate: Date = Date() {
        didSet {
            UserDefaults.standard.set(selectedDate.timeIntervalSince1970, forKey: transactionPeriodSelectedDateKey)
        }
    }

    /// Week / month / year scope; persisted for the whole app.
    var periodGranularity: TransactionPeriod = .month {
        didSet {
            UserDefaults.standard.set(periodGranularity.rawValue, forKey: transactionPeriodGranularityKey)
        }
    }

    var isLoading: Bool = false

    init() {
        if let raw = UserDefaults.standard.string(forKey: transactionPeriodGranularityKey),
           let stored = TransactionPeriod(rawValue: raw) {
            periodGranularity = stored
        }
        let ts = UserDefaults.standard.double(forKey: transactionPeriodSelectedDateKey)
        if ts > 0 {
            selectedDate = Date(timeIntervalSince1970: ts)
        }
    }

    // MARK: - Current period range

    var periodStart: Date {
        let cal = Calendar.current
        switch periodGranularity {
        case .week:
            return cal.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate.startOfMonth
        case .month:
            return selectedDate.startOfMonth
        case .year:
            return selectedDate.startOfYear
        }
    }

    var periodEnd: Date {
        let cal = Calendar.current
        switch periodGranularity {
        case .week:
            guard let interval = cal.dateInterval(of: .weekOfYear, for: selectedDate) else {
                return selectedDate
            }
            return interval.end.addingTimeInterval(-1)
        case .month:
            return selectedDate.endOfMonth
        case .year:
            return selectedDate.endOfYear
        }
    }

    /// Short title for the capsule (week range, month name, or year).
    var capsuleTitle: String {
        let cal = Calendar.current
        switch periodGranularity {
        case .week:
            guard let interval = cal.dateInterval(of: .weekOfYear, for: selectedDate) else {
                return selectedDate.monthYear
            }
            let start = interval.start
            let end = interval.end.addingTimeInterval(-1)
            let df = DateFormatter()
            df.dateFormat = "MMM d"
            let y1 = cal.component(.year, from: start)
            let y2 = cal.component(.year, from: end)
            if y1 == y2 {
                return "\(df.string(from: start)) – \(df.string(from: end)), \(y1)"
            }
            return "\(df.string(from: start)), \(y1) – \(df.string(from: end)), \(y2)"
        case .month:
            return selectedDate.monthYear
        case .year:
            return String(cal.component(.year, from: selectedDate))
        }
    }

    /// User-facing range label for empty states and subtitles.
    var periodDescription: String {
        switch periodGranularity {
        case .week:
            return capsuleTitle
        case .month:
            return selectedDate.monthYear
        case .year:
            return String(Calendar.current.component(.year, from: selectedDate))
        }
    }

    var isCurrentPeriod: Bool {
        let now = Date()
        let cal = Calendar.current
        switch periodGranularity {
        case .week:
            guard let interval = cal.dateInterval(of: .weekOfYear, for: selectedDate) else { return false }
            return interval.contains(now)
        case .month:
            return cal.isDate(selectedDate, equalTo: now, toGranularity: .month)
        case .year:
            return cal.isDate(selectedDate, equalTo: now, toGranularity: .year)
        }
    }

    // MARK: - Navigation

    func incrementPeriod() {
        let cal = Calendar.current
        switch periodGranularity {
        case .week:
            selectedDate = cal.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = selectedDate.nextMonth
        case .year:
            selectedDate = selectedDate.nextYear
        }
    }

    func decrementPeriod() {
        let cal = Calendar.current
        switch periodGranularity {
        case .week:
            selectedDate = cal.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = selectedDate.previousMonth
        case .year:
            selectedDate = selectedDate.previousYear
        }
    }

    func goToCurrentPeriod() {
        selectedDate = Date()
    }

    func goToDate(_ date: Date) {
        selectedDate = date
    }
}

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
    /// Anchor date for the visible time range; persisted so tabs and drill-downs stay aligned.
    var selectedDate: Date = Date() {
        didSet {
            UserDefaults.standard.set(selectedDate.timeIntervalSince1970, forKey: transactionPeriodSelectedDateKey)
        }
    }

    /// Time-range scope; persisted for the whole app.
    var periodGranularity: TransactionPeriod = .month {
        didSet {
            UserDefaults.standard.set(periodGranularity.rawValue, forKey: transactionPeriodGranularityKey)
        }
    }

    var isLoading: Bool = false

    init() {
        let raw = UserDefaults.standard.string(forKey: transactionPeriodGranularityKey)
        periodGranularity = TransactionPeriod(rawValue: raw ?? "") ?? .month

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
        case .threeMonths, .sixMonths:
            guard let count = periodGranularity.inclusiveRollingMonthCount else {
                return selectedDate.startOfMonth
            }
            return rollingMultiMonthStart(monthCount: count)
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
        case .month, .threeMonths, .sixMonths:
            return selectedDate.endOfMonth
        case .year:
            return selectedDate.endOfYear
        }
    }

    /// Short title for the capsule (week range, month, multi-month span, or year).
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
        case .threeMonths:
            return multiMonthCapsuleTitle(monthCount: 3)
        case .sixMonths:
            return multiMonthCapsuleTitle(monthCount: 6)
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
        case .threeMonths, .sixMonths:
            return capsuleTitle
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
        case .threeMonths, .sixMonths:
            guard let count = periodGranularity.inclusiveRollingMonthCount else { return false }
            let start = rollingMultiMonthStart(monthCount: count)
            let end = selectedDate.endOfMonth
            return now >= start && now <= end
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
        case .threeMonths:
            selectedDate = cal.date(byAdding: .month, value: 3, to: selectedDate) ?? selectedDate
        case .sixMonths:
            selectedDate = cal.date(byAdding: .month, value: 6, to: selectedDate) ?? selectedDate
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
        case .threeMonths:
            selectedDate = cal.date(byAdding: .month, value: -3, to: selectedDate) ?? selectedDate
        case .sixMonths:
            selectedDate = cal.date(byAdding: .month, value: -6, to: selectedDate) ?? selectedDate
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

    // MARK: - Rolling multi-month windows

    private func rollingMultiMonthStart(monthCount: Int) -> Date {
        let cal = Calendar.current
        let endMonthStart = selectedDate.startOfMonth
        return cal.date(byAdding: .month, value: -(monthCount - 1), to: endMonthStart) ?? endMonthStart
    }

    private func multiMonthCapsuleTitle(monthCount: Int) -> String {
        let cal = Calendar.current
        let start = rollingMultiMonthStart(monthCount: monthCount)
        let end = selectedDate.endOfMonth
        let y1 = cal.component(.year, from: start)
        let y2 = cal.component(.year, from: end)
        let df = DateFormatter()
        df.dateFormat = "MMM"
        let m1 = df.string(from: start)
        let m2 = df.string(from: end)
        if y1 == y2 {
            return "\(m1) – \(m2) \(y1)"
        }
        return "\(m1) \(y1) – \(m2) \(y2)"
    }
}

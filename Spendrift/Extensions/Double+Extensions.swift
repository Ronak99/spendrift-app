//
//  Double+Extensions.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

extension Double {
    /// Uses the user's locale and region currency (Settings → General → Language & Region).
    private static func currencyFormatter(maximumFractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let locale = Locale.autoupdatingCurrent
        formatter.locale = locale
        formatter.currencyCode = locale.currency?.identifier ?? "USD"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter
    }

    /// Currency with up to 2 decimal places; trailing zeros are stripped so whole
    /// unit amounts stay clean (e.g. $500, $99.50, €1.234,75 per locale rules).
    var formatCurrency: String {
        let formatter = Self.currencyFormatter(maximumFractionDigits: 2)
        return formatter.string(from: NSNumber(value: self))
            ?? formatter.string(from: NSNumber(value: 0))
            ?? "0"
    }

    /// Rounded currency with no fractional digits — for high-volume summaries
    /// where decimal noise reduces readability.
    var formatCurrencyRounded: String {
        let formatter = Self.currencyFormatter(maximumFractionDigits: 0)
        return formatter.string(from: NSNumber(value: self))
            ?? formatter.string(from: NSNumber(value: 0))
            ?? "0"
    }

    /// Whole-number string for amount/balance text fields (no decimals in the UI).
    var wholeAmountDisplayString: String {
        String(Int(self.rounded()))
    }
}

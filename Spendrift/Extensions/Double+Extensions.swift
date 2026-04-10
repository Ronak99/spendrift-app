//
//  Double+Extensions.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

extension Double {
    /// Currency with up to 2 decimal places; trailing zeros are stripped so whole
    /// rupee amounts remain clean (e.g. ₹500, ₹99.50, ₹1,234.75).
    var formatCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "₹0"
    }

    /// Rounded currency with no fractional digits — for high-volume summaries
    /// where decimal noise reduces readability (e.g. ₹12,450).
    var formatCurrencyRounded: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "₹0"
    }

    /// Whole-number string for amount/balance text fields (no decimals in the UI).
    var wholeAmountDisplayString: String {
        String(Int(self.rounded()))
    }
}

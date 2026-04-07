//
//  Double+Extensions.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

extension Double {
    /// Currency shown in lists, summaries, and toasts — no fractional digits.
    var formatCurrency: String {
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

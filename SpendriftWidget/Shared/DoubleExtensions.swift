//
//  DoubleExtensions.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

extension Double {
    /// Widget amounts use whole currency units for readability; symbols and grouping follow the user's locale.
    var formatCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let locale = Locale.autoupdatingCurrent
        formatter.locale = locale
        formatter.currencyCode = locale.currency?.identifier ?? "USD"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self))
            ?? formatter.string(from: NSNumber(value: 0))
            ?? "0"
    }
}

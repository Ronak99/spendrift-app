//
//  Date+Extensions.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

extension Date {
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }
    
    var endOfMonth: Date {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: self) else {
            return self
        }
        return monthInterval.end.addingTimeInterval(-1)
    }
    
    var nextMonth: Date {
        var components = DateComponents()
        components.month = 1
        return Calendar.current.date(byAdding: components, to: self) ?? self
    }
    
    var previousMonth: Date {
        var components = DateComponents()
        components.month = -1
        return Calendar.current.date(byAdding: components, to: self) ?? self
    }
    
    var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }
    
    var formatDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: self)
    }
    
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
    
    var month: Int {
        Calendar.current.component(.month, from: self)
    }
    
    var day: Int {
        Calendar.current.component(.day, from: self)
    }
}

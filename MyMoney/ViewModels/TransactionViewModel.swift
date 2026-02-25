//
//  TransactionViewModel.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftUI

@Observable
class TransactionViewModel {
    var selectedDate: Date = Date()
    var isLoading: Bool = false
    
    var startOfMonth: Date {
        selectedDate.startOfMonth
    }
    
    var endOfMonth: Date {
        selectedDate.endOfMonth
    }
    
    func incrementMonth() {
        selectedDate = selectedDate.nextMonth
    }
    
    func decrementMonth() {
        selectedDate = selectedDate.previousMonth
    }
}

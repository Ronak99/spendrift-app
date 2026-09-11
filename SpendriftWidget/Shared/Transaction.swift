//
//  Transaction.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID = UUID()
    var notes: String = ""
    var amount: Double = 0
    var date: Date = Date()
    var transactionType: TransactionType = TransactionType.expense
    var source: String = "manual"
    
    @Relationship var category: TransactionCategory?
    @Relationship var account: Account?
    
    init(
        id: UUID = UUID(),
        notes: String,
        amount: Double,
        date: Date = Date(),
        transactionType: TransactionType,
        category: TransactionCategory? = nil,
        account: Account? = nil,
        source: String = "manual"
    ) {
        self.id = id
        self.notes = notes
        self.amount = amount
        self.date = date
        self.transactionType = transactionType
        self.category = category
        self.account = account
        self.source = source
    }
}

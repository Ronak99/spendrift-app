//
//  Transaction.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var notes: String
    var amount: Double
    var date: Date
    var transactionType: TransactionType
    
    @Relationship var category: TransactionCategory?
    @Relationship var account: Account?
    
    init(
        id: UUID = UUID(),
        notes: String,
        amount: Double,
        date: Date = Date(),
        transactionType: TransactionType,
        category: TransactionCategory? = nil,
        account: Account? = nil
    ) {
        self.id = id
        self.notes = notes
        self.amount = amount
        self.date = date
        self.transactionType = transactionType
        self.category = category
        self.account = account
    }
}

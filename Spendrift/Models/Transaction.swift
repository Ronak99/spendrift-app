//
//  Transaction.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftData

/// How a transaction entered the ledger. Stored as a plain string for stable persistence.
enum TransactionSource: String {
    case manual
    case voice
    case pdf
    case receipt
    case shortcut
    case widget
    case sms
    case email
}

@Model
final class Transaction {
    var id: UUID = UUID()
    var notes: String = ""
    var amount: Double = 0
    var date: Date = Date()
    var transactionType: TransactionType = TransactionType.expense
    /// Capture path: manual, voice, pdf, receipt, shortcut, widget, sms.
    var source: String = TransactionSource.manual.rawValue
    
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
        source: String = TransactionSource.manual.rawValue
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

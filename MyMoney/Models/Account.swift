//
//  Account.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var balance: Double
    var createdOn: Date
    var icon: AccountIcon
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]?
    
    init(id: UUID = UUID(), name: String, balance: Double = 0, createdOn: Date = Date(), icon: AccountIcon = .unknown) {
        self.id = id
        self.name = name
        self.balance = balance
        self.createdOn = createdOn
        self.icon = icon
        self.transactions = []
    }
}

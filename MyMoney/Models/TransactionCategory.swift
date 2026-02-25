//
//  TransactionCategory.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftData

@Model
final class TransactionCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: CategoryType
    var createdOn: Date
    var icon: CategoryIcon
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
    var transactions: [Transaction]?
    
    init(id: UUID = UUID(), name: String, type: CategoryType, createdOn: Date = Date(), icon: CategoryIcon = .unknown) {
        self.id = id
        self.name = name
        self.type = type
        self.createdOn = createdOn
        self.icon = icon
        self.transactions = []
    }
}

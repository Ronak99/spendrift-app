//
//  VoiceTransactionPipelineTests.swift
//  MyMoneyTests
//
//  Created by Cursor on 23/03/26.
//

import Foundation
import SwiftData
import Testing
@testable import MyMoney

struct VoiceTransactionPipelineTests {
    @Test
    func parserExtractsAmountAndExpense() {
        let intent = TransactionIntentParser.parse("Paid 20rs to the cab driver")
        #expect(intent.amount == 20)
        #expect(intent.transactionType == .expense)
        #expect(intent.hints.contains("cab"))
    }

    @Test
    func categoryMatcherFindsTransportationForMetro() {
        let metroIntent = TransactionIntentParser.parse("I paid 120 rs in metro station")
        let categories = [
            TransactionCategory(name: "Transportation", type: .expense),
            TransactionCategory(name: "Shopping", type: .expense)
        ]

        let match = CategoryMatcher.match(intent: metroIntent, categories: categories)
        #expect(match.category?.name == "Transportation")
        #expect(match.confidence > 0.85)
    }

    @Test
    func creatorRequiresPrimaryAccount() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self,
            Account.self,
            TransactionCategory.self,
            configurations: config
        )
        let context = ModelContext(container)

        let account = Account(name: "SBI", balance: 1000, icon: .sbi, isPrimary: false)
        let category = TransactionCategory(name: "Transportation", type: .expense)
        context.insert(account)
        context.insert(category)

        let intent = TransactionIntentParser.parse("Paid 50 rs to cab")
        let match = CategoryMatcher.match(intent: intent, categories: [category])
        let result = VoiceTransactionCreator.createFromVoice(
            intent: intent,
            match: match,
            accounts: [account],
            categories: [category],
            modelContext: context
        )

        switch result {
        case .needsManualEntry(_, let failure):
            #expect(failure == .noPrimaryAccount)
        default:
            Issue.record("Expected noPrimaryAccount failure.")
        }
    }
}

//
//  ImportViewModel.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftUI
import PDFKit

@Observable
class ImportViewModel {
    var isLoading: Bool = false
    var showPrivacyInfo: Bool = true
    var selectedBank: BankType = .fi
    var selectedApp: CSVAppType = .myMoney
    var importedTransactions: [ImportedTransaction] = []
    var showPasswordAlert: Bool = false
    var passwordInput: String = ""
    var errorMessage: String = ""
    var showErrorAlert: Bool = false
    
    enum BankType: String, CaseIterable {
        case fi = "Fi (Federal Bank)"
        case sbi = "SBI (State Bank of India)"
        case hdfc = "HDFC Bank"
        case icici = "ICICI Bank"
    }
    
    enum CSVAppType: String, CaseIterable {
        case myMoney = "My Money"
        case other = "Other finance apps"
    }
}

struct ImportedTransaction: Identifiable {
    let id: UUID = UUID()
    var notes: String
    var amount: Double
    var date: Date
    var transactionType: TransactionType
    var account: Account?
    var category: TransactionCategory?
}

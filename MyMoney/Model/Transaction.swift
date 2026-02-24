//
//  Transaction.swift
//  MyMoney
//
//  Created by Ronak Punase on 03/08/25.
//


import SwiftUI
import Foundation

struct Transaction: Identifiable, Codable, Hashable {
    var id = UUID()
    let date: Date
    let rawDate: String  // Keep original format like "01 Jul"
    let receiverUPI: String
    let transactionDetails: String  // Full transaction string
    let amount: Decimal
    let balance: Decimal
    let transactionType: TransactionType
    
    enum TransactionType: String, Codable, CaseIterable {
        case upiOut = "UPIOUT"
        case nft = "NFT"
        case other = "OTHER"
    }
    
    // Formatted properties
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "₹\(formatter.string(from: amount as NSNumber) ?? "0.00")"
    }
    
    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "₹\(formatter.string(from: balance as NSNumber) ?? "0.00")"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: date)
    }
}

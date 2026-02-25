//
//  FiStatementParser.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import PDFKit

struct FiStatementParser: PDFParserProtocol {
    private let currentYear = Calendar.current.component(.year, from: .now)
    
    func parseTransactionsFromText(_ rawText: String) -> [ImportedTransaction] {
        var transactions: [ImportedTransaction] = []
        let lines = rawText.components(separatedBy: .newlines)
        
        var currentDate: String?
        var i = 0
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isDateLine(line) {
                currentDate = line
                i += 1
                continue
            }
            
            if let date = currentDate, isTransactionLine(line) {
                if let transaction = parseSingleLineTransaction(line: line, dateString: date) {
                    transactions.append(transaction)
                } else {
                    let multiLineResult = parseMultiLineTransaction(
                        startingAt: i,
                        lines: lines,
                        dateString: date
                    )
                    
                    if let transaction = multiLineResult.transaction {
                        transactions.append(transaction)
                        i = multiLineResult.nextIndex - 1
                    }
                }
            }
            
            i += 1
        }
        
        return transactions.sorted { $0.date < $1.date }
    }
    
    private func isDateLine(_ line: String) -> Bool {
        let datePattern = #"^\d{2}\s+[A-Za-z]{3}$"#
        return line.range(of: datePattern, options: .regularExpression) != nil
    }
    
    private func isTransactionLine(_ line: String) -> Bool {
        return line.contains("UPIOUT/") ||
        line.contains("NFT/") ||
        (line.contains("/") && containsAmountPattern(line))
    }
    
    private func containsAmountPattern(_ line: String) -> Bool {
        let amountPattern = #"\d{1,3}(,\d{2,3})*\.\d{2}"#
        return line.range(of: amountPattern, options: .regularExpression) != nil
    }
    
    private func parseSingleLineTransaction(line: String, dateString: String) -> ImportedTransaction? {
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 3 else { return nil }
        
        let balanceStr = components.last!
        let amountStr = components[components.count - 2]
        
        guard let amount = parseAmount(amountStr),
              let date = parseDate(dateString) else {
            return nil
        }
        
        let transactionDetails = components.dropLast(2).joined(separator: " ")
        let transactionType = determineTransactionType(from: transactionDetails)
        
        return ImportedTransaction(
            notes: transactionDetails,
            amount: abs(amount),
            date: date,
            transactionType: transactionType
        )
    }
    
    private func parseMultiLineTransaction(
        startingAt startIndex: Int,
        lines: [String],
        dateString: String
    ) -> (transaction: ImportedTransaction?, nextIndex: Int) {
        var combinedLine = ""
        var i = startIndex
        var foundAmountBalance = false
        
        while i < lines.count && !foundAmountBalance {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if line.isEmpty || isDateLine(line) {
                break
            }
            
            combinedLine += " " + line
            
            let components = combinedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 2 {
                let lastTwo = Array(components.suffix(2))
                if parseAmount(lastTwo[0]) != nil && parseAmount(lastTwo[1]) != nil {
                    foundAmountBalance = true
                }
            }
            
            i += 1
        }
        
        let transaction = parseSingleLineTransaction(line: combinedLine.trimmingCharacters(in: .whitespacesAndNewlines), dateString: dateString)
        return (transaction: transaction, nextIndex: i)
    }
    
    private func parseAmount(_ amountString: String) -> Double? {
        var cleanString = amountString
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let isNegative = cleanString.hasPrefix("(") && cleanString.hasSuffix(")")
        if isNegative {
            cleanString = String(cleanString.dropFirst().dropLast())
        }
        
        if let double = Double(cleanString) {
            return isNegative ? -double : double
        }
        
        return nil
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let dateWithYear = "\(dateString) \(currentYear)"
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.date(from: dateWithYear)
    }
    
    private func determineTransactionType(from transactionDetails: String) -> TransactionType {
        if transactionDetails.contains("UPIOUT") || transactionDetails.contains("DEBIT") {
            return .expense
        } else if transactionDetails.contains("CREDIT") || transactionDetails.contains("CR") {
            return .income
        } else {
            return .none
        }
    }
}

//
//  FiStatementParser.swift
//  MyMoney
//
//  Created by Ronak Punase on 03/08/25.
//
import Foundation
import PDFKit

struct FiStatementParser {
    private let currentYear = Calendar.current.component(.year, from: .now)
    
    func parseTransactionsFromText(from rawText: String) -> [Transaction] {
        var transactions: [Transaction] = []
        let lines = rawText.components(separatedBy: .newlines)
        
        var currentDate: String?
        var i = 0
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if this line is a date (format: "01 Jul", "02 Jul", etc.)
            if isDateLine(line) {
                currentDate = line
                i += 1
                continue
            }
            
            // If we have a current date and this looks like a transaction line
            if let date = currentDate, isTransactionLine(line) {
                // Parse single-line transaction
                if let transaction = parseSingleLineTransaction(line: line, dateString: date) {
                    transactions.append(transaction)
                } else {
                    // Try multi-line transaction parsing
                    let multiLineResult = parseMultiLineTransaction(
                        startingAt: i,
                        lines: lines,
                        dateString: date
                    )
                    
                    if let transaction = multiLineResult.transaction {
                        transactions.append(transaction)
                        i = multiLineResult.nextIndex - 1 // Will be incremented at end of loop
                    }
                }
            }
            
            i += 1
        }
        
        return transactions.sorted { $0.date < $1.date }
    }
    
    
    func extractTextFromPDF(_ pdfDocument: PDFDocument) -> String {
        var fullText = ""
        
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                if let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
        }
        
        return fullText
    }
    
    private func isDateLine(_ line: String) -> Bool {
        // Pattern: "01 Jul", "02 Jul", etc.
        let datePattern = #"^\d{2}\s+[A-Za-z]{3}$"#
        return line.range(of: datePattern, options: .regularExpression) != nil
    }
    
    private func isTransactionLine(_ line: String) -> Bool {
        // Check if line contains transaction patterns
        return line.contains("UPIOUT/") ||
        line.contains("NFT/") ||
        (line.contains("/") && containsAmountPattern(line))
    }
    
    private func containsAmountPattern(_ line: String) -> Bool {
        // Look for amount patterns like "1,21,496.00" or "159.40"
        let amountPattern = #"\d{1,3}(,\d{2,3})*\.\d{2}"#
        return line.range(of: amountPattern, options: .regularExpression) != nil
    }
    
    private func parseSingleLineTransaction(line: String, dateString: String) -> Transaction? {
        // Try to extract amount and balance from the end of the line
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 3 else { return nil }
        
        // Last two components should be amount and balance
        let balanceStr = components.last!
        let amountStr = components[components.count - 2]
        
        guard let amount = parseAmount(amountStr),
              let balance = parseAmount(balanceStr),
              let date = parseDate(dateString) else {
            return nil
        }
        
        // Extract transaction details (everything except last two components)
        let transactionDetails = components.dropLast(2).joined(separator: " ")
        let receiverUPI = extractReceiverUPI(from: transactionDetails)
        let transactionType = determineTransactionType(from: transactionDetails)
        
        return Transaction(
            date: date,
            rawDate: dateString,
            receiverUPI: receiverUPI,
            transactionDetails: transactionDetails,
            amount: amount,
            balance: balance,
            transactionType: transactionType
        )
    }
    
    private func parseMultiLineTransaction(
        startingAt startIndex: Int,
        lines: [String],
        dateString: String
    ) -> (transaction: Transaction?, nextIndex: Int) {
        
        var combinedLine = ""
        var i = startIndex
        var foundAmountBalance = false
        
        // Combine lines until we find amount and balance
        while i < lines.count && !foundAmountBalance {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Stop if we hit another date or empty line
            if line.isEmpty || isDateLine(line) {
                break
            }
            
            combinedLine += " " + line
            
            // Check if this combined line now has amount and balance
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
    
    private func parseAmount(_ amountString: String) -> Decimal? {
        // Clean the string - remove currency symbols and spaces
        var cleanString = amountString
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle negative amounts in parentheses
        let isNegative = cleanString.hasPrefix("(") && cleanString.hasSuffix(")")
        if isNegative {
            cleanString = String(cleanString.dropFirst().dropLast())
        }
        
        // Convert to decimal
        if let decimal = Decimal(string: cleanString) {
            return isNegative ? -decimal : decimal
        }
        
        return nil
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // Format: "01 Jul" - we need to add the year
        let dateWithYear = "\(dateString) \(currentYear)"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        
        return formatter.date(from: dateWithYear)
    }
    
    private func extractReceiverUPI(from transactionDetails: String) -> String {
        // Extract UPI ID patterns
        let upiPatterns = [
            #"[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,  // Standard UPI format
            #"[a-zA-Z0-9._-]+@[a-zA-Z]+"#  // Simplified UPI format
        ]
        
        for pattern in upiPatterns {
            if let range = transactionDetails.range(of: pattern, options: .regularExpression) {
                return String(transactionDetails[range])
            }
        }
        
        // If no UPI pattern found, try to extract from transaction ID
        if transactionDetails.contains("UPIOUT/") {
            let components = transactionDetails.components(separatedBy: "/")
            if components.count >= 3 {
                // Usually the UPI is in the 3rd component
                let upiComponent = components[2]
                if upiComponent.contains("@") {
                    return upiComponent
                }
            }
        }
        
        return "Unknown"
    }
    
    private func determineTransactionType(from transactionDetails: String) -> Transaction.TransactionType {
        if transactionDetails.contains("UPIOUT") {
            return .upiOut
        } else if transactionDetails.contains("NFT") {
            return .nft
        } else {
            return .other
        }
    }
}

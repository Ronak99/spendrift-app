//
//  CSVParserService.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

class CSVParserService {
    func parseCSV(from url: URL, app: ImportViewModel.CSVAppType) async throws -> [ImportedTransaction] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        guard !lines.isEmpty else {
            throw CSVParserError.emptyFile
        }
        
        // Parse header
        let header = lines[0].components(separatedBy: ",")
        
        // Map columns based on app type
        let columnMap = getColumnMap(for: app, header: header)
        
        var transactions: [ImportedTransaction] = []
        
        // Parse data rows
        for (index, line) in lines.enumerated() {
            guard index > 0, !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            
            let columns = parseCSVLine(line)
            
            guard let transaction = parseTransaction(
                columns: columns,
                columnMap: columnMap
            ) else {
                continue
            }
            
            transactions.append(transaction)
        }
        
        return transactions
    }
    
    private func getColumnMap(for app: ImportViewModel.CSVAppType, header: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        
        for (index, column) in header.enumerated() {
            let normalized = column.lowercased().trimmingCharacters(in: .whitespaces)
            
            switch normalized {
            case "date", "transaction_date":
                map["date"] = index
            case "amount", "transaction_amount":
                map["amount"] = index
            case "notes", "description", "memo":
                map["notes"] = index
            case "type", "transaction_type":
                map["type"] = index
            default:
                break
            }
        }
        
        return map
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        // Simple CSV parsing - handles quoted fields
        var columns: [String] = []
        var currentColumn = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                columns.append(currentColumn.trimmingCharacters(in: .whitespaces))
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        columns.append(currentColumn.trimmingCharacters(in: .whitespaces))
        
        return columns
    }
    
    private func parseTransaction(columns: [String], columnMap: [String: Int]) -> ImportedTransaction? {
        guard let dateIndex = columnMap["date"],
              let amountIndex = columnMap["amount"],
              let notesIndex = columnMap["notes"],
              dateIndex < columns.count,
              amountIndex < columns.count,
              notesIndex < columns.count else {
            return nil
        }
        
        let dateString = columns[dateIndex]
        let amountString = columns[amountIndex]
        let notes = columns[notesIndex]
        
        guard let date = parseDate(dateString),
              let amount = Double(amountString.replacingOccurrences(of: ",", with: "")) else {
            return nil
        }
        
        let typeIndex = columnMap["type"]
        let typeString = typeIndex != nil && typeIndex! < columns.count ? columns[typeIndex!] : ""
        let transactionType = parseTransactionType(typeString, amount: amount)
        
        return ImportedTransaction(
            notes: notes,
            amount: abs(amount),
            date: date,
            transactionType: transactionType
        )
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd",
            "dd-MM-yyyy",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy/MM/dd"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func parseTransactionType(_ typeString: String, amount: Double) -> TransactionType {
        let normalized = typeString.lowercased()
        
        if normalized.contains("expense") || normalized.contains("debit") || normalized.contains("out") {
            return .expense
        } else if normalized.contains("income") || normalized.contains("credit") || normalized.contains("in") {
            return .income
        } else {
            // Infer from amount sign
            return amount < 0 ? .expense : .income
        }
    }
}

enum CSVParserError: LocalizedError {
    case emptyFile
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "CSV file is empty"
        case .invalidFormat:
            return "Invalid CSV format"
        }
    }
}

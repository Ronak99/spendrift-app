//
//  PDFParserService.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import PDFKit

class PDFParserService {
    func getParser(for bank: ImportViewModel.BankType) -> PDFParserProtocol {
        switch bank {
        case .fi:
            return FiStatementParser()
        case .sbi:
            return SBIStatementParser()
        case .hdfc:
            return HDFCStatementParser()
        case .icici:
            return ICICIStatementParser()
        }
    }
    
    func parsePDF(from url: URL, bank: ImportViewModel.BankType, password: String?) async throws -> [ImportedTransaction] {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFParserError.failedToLoadDocument
        }
        
        if pdfDocument.isEncrypted {
            guard let password = password else {
                throw PDFParserError.passwordRequired
            }
            
            if !pdfDocument.unlock(withPassword: password) {
                throw PDFParserError.invalidPassword
            }
        }
        
        let parser = getParser(for: bank)
        let text = parser.extractTextFromPDF(pdfDocument)
        let transactions = parser.parseTransactionsFromText(text)
        
        return transactions
    }
}

enum PDFParserError: LocalizedError {
    case failedToLoadDocument
    case passwordRequired
    case invalidPassword
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadDocument:
            return "Failed to load PDF document"
        case .passwordRequired:
            return "PDF is password protected"
        case .invalidPassword:
            return "Invalid password"
        }
    }
}

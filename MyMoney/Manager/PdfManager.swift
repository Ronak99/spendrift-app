//
//  PdfManager.swift
//  MyMoney
//
//  Created by Ronak Punase on 03/08/25.
//

import SwiftUI
import PDFKit
import Foundation

@Observable
class PdfManager {
    private var pendingPDFDocument: PDFDocument?
    private let defaultPassword = "RONA10005"
    
    private let parser: FiStatementParser = FiStatementParser()
    
    var transactions: [Transaction] = []
    var isProcessing = false
    var showPasswordAlert = false
    var showErrorAlert = false
    var passwordInput = ""
    var errorMessage = ""
    var extractionResult: PDFExtractionResult?
    var rawText = ""
    
    func extractDataFromPDF() {
        guard let pdfURL = Bundle.main.url(forResource: "statement", withExtension: "pdf") else {
            showError("PDF file not found in app bundle")
            return
        }
        
        loadAndExtractPDF(from: pdfURL, password: defaultPassword)
    }
    
    func loadAndExtractPDF(from url: URL, password: String) {
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            guard let pdfDocument = PDFDocument(url: url) else {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    self?.showError("Failed to load PDF document")
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.processPDFDocument(pdfDocument, password: password, startTime: startTime)
            }
        }
    }
    
    private func processPDFDocument(_ pdfDocument: PDFDocument, password: String, startTime: CFAbsoluteTime) {
        if pdfDocument.isEncrypted {
            print("PDF is encrypted, attempting to unlock...")
            
            if pdfDocument.unlock(withPassword: password) {
                print("PDF unlocked successfully")
                extractDataFromDocument(pdfDocument, startTime: startTime)
            } else {
                print("Failed to unlock PDF with provided password")
                pendingPDFDocument = pdfDocument
                passwordInput = ""
                showPasswordAlert = true
                isProcessing = false
            }
        } else {
            print("PDF is not encrypted")
            extractDataFromDocument(pdfDocument, startTime: startTime)
        }
    }
    
    private func extractDataFromDocument(_ pdfDocument: PDFDocument, startTime: CFAbsoluteTime) {
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            let extractedText = self?.parser.extractTextFromPDF(pdfDocument) ?? ""
//            let transactions = self?.parser.parseTransactionsFromText(extractedText) ?? []
//            
//            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
//            
//            let result = PDFExtractionResult(
//                transactions: transactions,
//                extractedText: extractedText,
//                pageCount: pdfDocument.pageCount,
//                processingTime: processingTime
//            )
//          
//            DispatchQueue.main.async {
//                self?.isProcessing = false
//                self?.transactions = transactions
//                self?.extractionResult = result
//                self?.rawText = extractedText
//                
//                print("Extraction completed:")
//                print("- Pages processed: \(pdfDocument.pageCount)")
//                print("- Transactions found: \(transactions.count)")
//                print("- Processing time: \(String(format: "%.2f", processingTime))s")
//            }
//        }
    }
    
    func unlockWithPassword() {
        guard let pdfDocument = pendingPDFDocument else { return }
        
        if pdfDocument.unlock(withPassword: passwordInput) {
            let startTime = CFAbsoluteTimeGetCurrent()
            extractDataFromDocument(pdfDocument, startTime: startTime)
            pendingPDFDocument = nil
            showPasswordAlert = false
            passwordInput = ""
        } else {
            showError("Incorrect password. Please try again.")
        }
    }
    
    func cancelPasswordPrompt() {
        pendingPDFDocument = nil
        passwordInput = ""
        showPasswordAlert = false
        isProcessing = false
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        print("Error: \(message)")
    }
}

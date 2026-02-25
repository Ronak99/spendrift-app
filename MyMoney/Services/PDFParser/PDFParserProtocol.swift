//
//  PDFParserProtocol.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import PDFKit

protocol PDFParserProtocol {
    func extractTextFromPDF(_ pdfDocument: PDFDocument) -> String
    func parseTransactionsFromText(_ text: String) -> [ImportedTransaction]
}

extension PDFParserProtocol {
    func extractTextFromPDF(_ pdfDocument: PDFDocument) -> String {
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        return fullText
    }
}

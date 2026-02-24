import SwiftUI
import PDFKit
import Foundation

struct PDFExtractionResult {
    let transactions: [Transaction]
    let extractedText: String
    let pageCount: Int
    let processingTime: TimeInterval
}
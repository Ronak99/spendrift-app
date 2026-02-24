//
//  PDFExtractionResult.swift
//  MyMoney
//
//  Created by Ronak Punase on 03/08/25.
//


import SwiftUI
import PDFKit
import Foundation

struct PDFExtractionResult {
    let transactions: [Transaction]
    let extractedText: String
    let pageCount: Int
    let processingTime: TimeInterval
}
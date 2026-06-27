//
//  ReceiptExpensePipelineService.swift
//  Spendrift
//

import Foundation
import SwiftData

enum ReceiptPipelineError: Error {
    case aiService(String)
}

struct ReceiptExpensePipelineService {
    var receiptService = ReceiptTransactionService()

    @MainActor
    func submitImage(
        imageData: Data,
        mimeType: String,
        filename: String,
        accounts: [Account],
        categories: [TransactionCategory],
        modelContext: ModelContext
    ) async -> Result<ReceiptCreateResult, ReceiptPipelineError> {
        do {
            let payload = try await receiptService.parseReceipt(
                imageData: imageData,
                mimeType: mimeType,
                filename: filename,
                categories: categories
            )

            let result = ReceiptTransactionCreator.createFromReceipt(
                payload: payload,
                accounts: accounts,
                categories: categories,
                modelContext: modelContext
            )
            return .success(result)
        } catch {
            return .failure(.aiService(error.localizedDescription))
        }
    }
}

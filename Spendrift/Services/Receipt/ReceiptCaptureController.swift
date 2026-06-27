//
//  ReceiptCaptureController.swift
//  Spendrift
//
//  Drives the in-app "Scan receipt" flow: prepare image, send to the backend,
//  then either create the transaction or surface the "missing fields" review sheet.
//

import Foundation
import SwiftData
import UIKit

@Observable
@MainActor
final class ReceiptCaptureController {
    enum State: Equatable {
        case idle
        case processing
        case error(String)
    }

    private(set) var state: State = .idle
    /// Set when the parsed receipt needs user review (missing/uncertain fields).
    var reviewPayload: VoiceInlineManualSheetPayload?
    /// Toggles when a transaction was created directly so the view can dismiss.
    private(set) var didCreate = false

    private let pipeline = ReceiptExpensePipelineService()

    var isProcessing: Bool { state == .processing }

    func process(
        image: UIImage,
        accounts: [Account],
        categories: [TransactionCategory],
        modelContext: ModelContext
    ) {
        guard state != .processing else { return }

        guard let prepared = ReceiptImagePreparer.prepare(image) else {
            state = .error("Couldn't process this image. Try a different photo.")
            Analytics.capture(.receiptScanFailed, [Analytics.Key.reason: "image_prepare_failed"])
            return
        }

        runPipeline(
            imageData: prepared.data,
            mimeType: prepared.mimeType,
            filename: prepared.filename,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext
        )
    }

    /// Process an image handed off from the Share Extension (stored in the App Group).
    /// Deletes `fileURL` when finished.
    func processSharedImage(
        fileURL: URL,
        accounts: [Account],
        categories: [TransactionCategory],
        modelContext: ModelContext
    ) {
        guard state != .processing else { return }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            ReceiptShareInbox.removeFileIfPresent(fileURL)
            state = .error("Couldn't read the shared image. Try sharing it again.")
            Analytics.capture(.receiptScanFailed, [Analytics.Key.reason: "shared_image_unreadable"])
            return
        }

        guard let prepared = ReceiptImagePreparer.prepare(data: data) else {
            ReceiptShareInbox.removeFileIfPresent(fileURL)
            state = .error("Couldn't process the shared image. Try a different one.")
            Analytics.capture(.receiptScanFailed, [Analytics.Key.reason: "image_prepare_failed"])
            return
        }

        ReceiptShareInbox.removeFileIfPresent(fileURL)
        runPipeline(
            imageData: prepared.data,
            mimeType: prepared.mimeType,
            filename: prepared.filename,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext
        )
    }

    func dismissError() {
        if case .error = state { state = .idle }
    }

    func acknowledgeCreate() {
        didCreate = false
    }

    private func runPipeline(
        imageData: Data,
        mimeType: String,
        filename: String,
        accounts: [Account],
        categories: [TransactionCategory],
        modelContext: ModelContext
    ) {
        state = .processing
        Task {
            let result = await pipeline.submitImage(
                imageData: imageData,
                mimeType: mimeType,
                filename: filename,
                accounts: accounts,
                categories: categories,
                modelContext: modelContext
            )

            switch result {
            case .success(let createResult):
                handleCreateResult(createResult)
            case .failure(let pipelineError):
                Analytics.capture(.receiptScanFailed, [Analytics.Key.reason: "pipeline_error"])
                state = .error(pipelineErrorMessage(pipelineError))
            }
        }
    }

    private func handleCreateResult(_ result: ReceiptCreateResult) {
        switch result {
        case .created:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            didCreate = true
            state = .idle
        case .needsManualEntry(let draft, _, let hint):
            reviewPayload = VoiceInlineManualSheetPayload(draft: draft, hint: hint)
            state = .idle
        }
    }

    private func pipelineErrorMessage(_ error: ReceiptPipelineError) -> String {
        switch error {
        case .aiService(let message):
            return message
        }
    }
}

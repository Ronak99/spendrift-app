//
//  ProFeature.swift
//  Spendrift
//
//  The four AI-backed features that Spendrift Pro unlocks. Everything else in the
//  app — manual entry, accounts, categories, charts, widgets, Shortcuts — stays free.
//
//  Raw values intentionally match the `method` strings already used by
//  `Analytics.captureTransactionCreated`, so paywall funnels join cleanly to the
//  existing `transaction_created` events.
//

import Foundation

enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case voice = "voice"
    case messageImport = "sms"
    case statementImport = "pdf"
    case receiptScan = "receipt"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .voice:           "Voice capture"
        case .messageImport:   "SMS auto-import"
        case .statementImport: "Statement import"
        case .receiptScan:     "Receipt scan"
        }
    }

    var symbolName: String {
        switch self {
        case .voice:           "mic.fill"
        case .messageImport:   "message.fill"
        case .statementImport: "doc.text.fill"
        case .receiptScan:     "doc.viewfinder.fill"
        }
    }

    /// Short line used in the paywall's feature list.
    var summary: String {
        switch self {
        case .voice:           "Say it, and it's logged — amount, category, account."
        case .messageImport:   "Bank SMS turn into transactions automatically."
        case .statementImport: "Drop in a PDF statement, get every row back."
        case .receiptScan:     "Photograph a receipt and skip the typing."
        }
    }

    /// Headline for the celebration paywall shown after this feature's first success.
    var celebrationHeadline: String {
        switch self {
        case .voice:           "That was Spendrift Pro"
        case .messageImport:   "Those came in on their own"
        case .statementImport: "That statement read itself"
        case .receiptScan:     "That receipt read itself"
        }
    }

    /// Free uses per calendar month before the feature is gated.
    ///
    /// Sized so every user can build the habit before being asked to pay, while the
    /// most expensive call (a whole PDF) is the tightest. Revisit against real
    /// per-call cost in the backend's OpenAI usage.
    var monthlyFreeQuota: Int {
        switch self {
        case .voice:           10
        case .messageImport:   30
        case .statementImport: 1
        case .receiptScan:     5
        }
    }

    /// Unit noun for quota copy, e.g. "10 voice notes left this month".
    func unitLabel(count: Int) -> String {
        switch self {
        case .voice:           count == 1 ? "voice note" : "voice notes"
        case .messageImport:   count == 1 ? "message" : "messages"
        case .statementImport: count == 1 ? "statement" : "statements"
        case .receiptScan:     count == 1 ? "receipt" : "receipts"
        }
    }
}

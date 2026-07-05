//
//  ReceiptSharePayload.swift
//  Spendrift
//
//  Identifies a receipt image handed off from the Share Extension so the app can
//  process it once (keyed by `id`) via a SwiftUI `.task(id:)`.
//

import Foundation

struct ReceiptSharePayload: Equatable {
    let id: UUID
    let fileURL: URL
}

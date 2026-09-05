//
//  CategoryEventSource.swift
//  Spendrift
//

import Foundation

/// Low-cardinality source dimension for category catalog analytics (RON-85).
enum CategoryEventSource: String {
    case manual
    case migration
}

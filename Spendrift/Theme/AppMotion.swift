//
//  AppMotion.swift
//  Spendrift
//
//  Shared spring for wash and enamel colour changes so editors and trays
//  interpolate the same way. Nil when Reduce Motion is on.
//

import SwiftUI

enum AppMotion {
    static func wash(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)
    }

    /// Stable animation key for `Color(hex:)` so a new instance of the same
    /// swatch does not retrigger interpolation.
    static func colorToken(_ color: Color) -> String {
        color.hexString ?? ""
    }
}

extension View {
    /// Springs this view when `value` changes, but not on first appearance.
    /// Apply only on colour leaves so sheet present/dismiss stay system-native.
    func washMotion<Value: Equatable>(value: Value) -> some View {
        modifier(WashMotionModifier(value: value))
    }
}

private struct WashMotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var allowsMotion = false
    let value: Value

    func body(content: Content) -> some View {
        content
            .animation(allowsMotion ? AppMotion.wash(reduceMotion) : nil, value: value)
            .onAppear {
                DispatchQueue.main.async {
                    allowsMotion = true
                }
            }
    }
}

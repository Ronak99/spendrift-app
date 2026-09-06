//
//  ProPaywallPresenter.swift
//  Spendrift
//
//  Shared plumbing for the screens that can start an AI feature.
//
//  The service layer is the hard gate — it refuses the backend call whatever the
//  caller does. This is the courteous one: it checks first, so a user with no credits
//  left sees the paywall instead of starting a recording that is going to fail.
//

import SwiftUI

extension View {
    /// Attaches the Pro paywall to this view, driven by a `PaywallContext?` binding.
    func proPaywall(_ context: Binding<PaywallContext?>) -> some View {
        sheet(item: context) { resolved in
            ProPaywallView(context: resolved)
        }
    }
}

@MainActor
enum ProAccess {
    /// Runs `action` when the feature is available, and routes to the paywall when it
    /// is not. `announce: false` on the block because this presents the paywall
    /// locally — letting the root queue also broadcast would show it twice.
    static func attempt(
        _ feature: ProFeature,
        paywall: Binding<PaywallContext?>,
        action: () -> Void
    ) {
        switch ProGate.evaluate(feature) {
        case .unlimited, .allowed:
            action()
        case .blocked(let blocked):
            ProGate.reportBlocked(blocked, announce: false)
            paywall.wrappedValue = .quotaExhausted(blocked)
        }
    }
}

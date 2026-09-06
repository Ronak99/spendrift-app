//
//  ProStatusSettingsView.swift
//  Spendrift
//
//  Settings rows for Spendrift Pro: current plan or trial countdown when subscribed,
//  and the remaining free allowance per AI feature when not.
//
//  Showing the free tier's remaining credits here is deliberate. A quota the user
//  cannot see is indistinguishable from a bug the first time it stops them, and
//  App Review expects a visible Restore Purchases path besides.
//

import SwiftUI
import StoreKit

struct ProSettingsRows: View {
    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex

    @State private var entitlement = ProEntitlement.shared
    @State private var paywallContext: PaywallContext?
    @State private var showManageSubscriptions = false
    @State private var restoreMessage: String?

    private var accent: Color { Color.accentColor(forThemeIndex: selectedThemeIndex) }
    private var accentSoft: Color { accent.opacity(0.16) }

    var body: some View {
        Group {
            if entitlement.isPro {
                subscribedRows
            } else {
                freeTierRows
            }
        }
        .proPaywall($paywallContext)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .alert("Restore purchases", isPresented: Binding(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )) {
            Button("OK", role: .cancel) { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
        .task {
            await entitlement.loadProducts()
        }
    }

    // MARK: - Subscribed

    private var subscribedRows: some View {
        Group {
            SettingsListItem(
                icon: "sparkles",
                title: "Spendrift Pro",
                subtitle: subscribedSubtitle,
                accent: accent,
                accentSoft: accentSoft,
                accessory: .value("Active")
            )
            .listItemPositioned(index: 0, count: 2)

            Button {
                showManageSubscriptions = true
            } label: {
                SettingsListItem(
                    icon: "creditcard",
                    title: "Manage subscription",
                    accent: accent,
                    accentSoft: accentSoft,
                    accessory: .chevron
                )
                .listItemPositioned(index: 1, count: 2)
            }
            .buttonStyle(.plain)
        }
    }

    private var subscribedSubtitle: String {
        if let trialEndsAt = entitlement.trialEndsAt {
            return "Free trial ends \(trialEndsAt.formatted(.dateTime.day().month(.abbreviated)))"
        }
        if case .subscribed(let expiresAt) = entitlement.status, let expiresAt {
            return "Renews \(expiresAt.formatted(.dateTime.day().month(.abbreviated)))"
        }
        return "Unlimited voice, SMS, statements and receipts"
    }

    // MARK: - Free tier

    private var freeTierRows: some View {
        Group {
            Button {
                paywallContext = entitlement.status == .lapsed ? .winback : .settings
            } label: {
                SettingsListItem(
                    icon: "sparkles",
                    title: "Spendrift Pro",
                    subtitle: upgradeSubtitle,
                    accent: accent,
                    accentSoft: accentSoft,
                    accessory: .chevron
                )
                .listItemPositioned(index: 0, count: rowCount)
            }
            .buttonStyle(.plain)

            ForEach(Array(ProFeature.allCases.enumerated()), id: \.element.id) { index, feature in
                SettingsListItem(
                    icon: feature.symbolName,
                    title: feature.displayName,
                    subtitle: "Refills \(AIQuotaStore.nextResetDate().formatted(.dateTime.day().month(.abbreviated)))",
                    accent: accent,
                    accentSoft: accentSoft,
                    accessory: .value(remainingLabel(for: feature))
                )
                .listItemPositioned(index: index + 1, count: rowCount)
            }

            Button {
                Task { await restore() }
            } label: {
                SettingsListItem(
                    icon: "arrow.clockwise",
                    title: "Restore purchases",
                    accent: accent,
                    accentSoft: accentSoft,
                    accessory: .chevron
                )
                .listItemPositioned(index: rowCount - 1, count: rowCount)
            }
            .buttonStyle(.plain)
        }
    }

    /// Pro row + one row per feature + restore.
    private var rowCount: Int { ProFeature.allCases.count + 2 }

    private var upgradeSubtitle: String {
        entitlement.status == .lapsed
            ? "Your subscription has ended"
            : (entitlement.isEligibleForTrial ? "7 days free, then unlimited" : "Unlimited AI capture")
    }

    private func remainingLabel(for feature: ProFeature) -> String {
        let remaining = AIQuotaStore.remaining(feature)
        return "\(remaining) of \(feature.monthlyFreeQuota) left"
    }

    private func restore() async {
        let restored = await entitlement.restorePurchases()
        Analytics.capturePro(.restoreCompleted, [Analytics.Key.granted: restored])
        restoreMessage = restored
            ? "Spendrift Pro is active on this device."
            : "No previous Spendrift Pro purchase was found on this Apple Account."
    }
}

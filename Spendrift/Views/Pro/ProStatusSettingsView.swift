//
//  ProStatusSettingsView.swift
//  Spendrift
//
//  Settings rows for Spendrift Pro: current plan or trial countdown when subscribed,
//  and a single "Pro Stats" row when not, opening into this month's remaining free
//  allowance for all four AI features at once.
//
//  Showing the free tier's remaining credits here is deliberate. A quota the user
//  cannot see is indistinguishable from a bug the first time it stops them, and
//  App Review expects a visible Restore Purchases path besides. They are folded into
//  one expandable row so four near-identical counters do not outweigh the rest of
//  the section.
//

import SwiftUI
import StoreKit

struct ProSettingsRows: View {
    @Binding var paywallContext: PaywallContext?

    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex

    @State private var entitlement = ProEntitlement.shared
    @State private var showManageSubscriptions = false
    @State private var isStatsExpanded = false
    @State private var restoreMessage: String?

    private var accent: Color { Color.accentColor(forThemeIndex: selectedThemeIndex) }

    var body: some View {
        Group {
            if entitlement.isPro {
                subscribedRows
            } else {
                freeTierRows
            }
        }
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
                    accessory: .chevron
                )
                .listItemPositioned(index: 0, count: rowCount)
            }
            .buttonStyle(.plain)

            statsRowHeader
                .listItemPositioned(isStatsExpanded ? .expandedHeader : .middle)
                .listRowSeparator(isStatsExpanded ? .hidden : .visible, edges: .bottom)

            if isStatsExpanded {
                ProStatsRingsView()
                    .listItemPositioned(.expandedBody)
                    .listRowSeparator(.hidden, edges: .top)
            }

            Button {
                Task { await restore() }
            } label: {
                SettingsListItem(
                    icon: "arrow.clockwise",
                    title: "Restore purchases",
                    accent: accent,
                    accessory: .chevron
                )
                .listItemPositioned(index: rowCount - 1, count: rowCount)
            }
            .buttonStyle(.plain)
        }
    }

    /// Pro + Pro Stats (+ rings when open) + Restore.
    private var rowCount: Int { isStatsExpanded ? 4 : 3 }

    private var statsRowHeader: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                isStatsExpanded.toggle()
            }
        } label: {
            SettingsListItem(
                icon: "circle.dotted.circle",
                title: "Pro Stats",
                subtitle: "Refills \(AIQuotaStore.nextResetDate().formatted(.dateTime.day().month(.abbreviated)))",
                accent: accent,
                accessory: .valueDisclosure(usedPercentLabel, isExpanded: isStatsExpanded)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var usedPercentLabel: String {
        "\(ProStat.averageUsedPercent(ProStat.currentMonth()))% used"
    }

    private var upgradeSubtitle: String {
        entitlement.status == .lapsed
            ? "Your subscription has ended"
            : (entitlement.isEligibleForTrial ? "7 days free, then unlimited" : "Unlimited AI capture")
    }

    private func restore() async {
        let restored = await entitlement.restorePurchases()
        Analytics.capturePro(.restoreCompleted, [Analytics.Key.granted: restored])
        restoreMessage = restored
            ? "Spendrift Pro is active on this device."
            : "No previous Spendrift Pro purchase was found on this Apple Account."
    }
}

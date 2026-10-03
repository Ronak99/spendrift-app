//
//  ProPaywallView.swift
//  Spendrift
//
//  The Spendrift Pro paywall. One view, four contexts — the copy changes, the
//  offer does not.
//
//  The important one is `.celebration`, shown immediately after the first
//  successful voice note / SMS import / statement import / receipt scan. It arrives
//  on the payoff, framed as "Pro just did that", not as a wall in front of the
//  feature. Everything else in the app stays free, so a user who dismisses this can
//  keep tracking manually forever.
//

import SwiftUI
import StoreKit

enum PaywallContext: Equatable, Identifiable {
    /// First successful use of an AI feature — the value moment.
    case celebration(ProFeature)
    /// Free monthly quota for this feature is spent.
    case quotaExhausted(ProFeature)
    /// Opened deliberately from Settings.
    case settings
    /// Previously subscribed, now lapsed.
    case winback

    var id: String {
        switch self {
        case .celebration(let feature):   "celebration.\(feature.rawValue)"
        case .quotaExhausted(let feature): "quota.\(feature.rawValue)"
        case .settings:                    "settings"
        case .winback:                     "winback"
        }
    }

    /// Low-cardinality analytics label.
    var analyticsName: String {
        switch self {
        case .celebration:    "celebration"
        case .quotaExhausted: "quota_exhausted"
        case .settings:       "settings"
        case .winback:        "winback"
        }
    }

    var feature: ProFeature? {
        switch self {
        case .celebration(let feature), .quotaExhausted(let feature): feature
        case .settings, .winback: nil
        }
    }
}

struct ProPaywallView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @State private var entitlement = ProEntitlement.shared
    @State private var selectedPlan: ProEntitlement.Plan = .yearly
    @State private var errorMessage: String?
    @State private var showPendingNotice = false
    @State private var isRestoring = false

    private let accent = OnboardingTheme.accent
    private let privacyPolicyURL = URL(string: "https://spendrift.ronakpunase.dev/privacy_policy")!
    // Apple's standard EULA — the default terms for an app with no custom agreement.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            paywall
                // An empty title keeps the inline bar from collapsing, which is
                // what gives the system close button a place to live.
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.visible, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.clear, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar { closeToolbar }
        }
        .preferredColorScheme(.dark)
        .task {
            await entitlement.loadProducts()
        }
        .onAppear {
            PaywallSeenStore.markSeen()
            Analytics.capturePro(.paywallViewed, analyticsProperties)
        }
        .onDisappear {
            guard !entitlement.isPro else { return }
            Analytics.capturePro(.paywallDismissed, analyticsProperties)
        }
    }

    private var paywall: some View {
        ZStack(alignment: .bottom) {
            OnboardingSheetAtmosphericBackground(tintColor: accent)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 8)
                        .padding(.bottom, 28)

                    featureCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    planSelector
                        .padding(.horizontal, 20)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "#FF6B6B"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 16)
                    }

                    if showPendingNotice {
                        Text("Your purchase is waiting on approval. Pro unlocks as soon as it clears.")
                            .font(.footnote)
                            .foregroundStyle(OnboardingTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 16)
                    }

                    // Room for the pinned action stack.
                    Color.clear.frame(height: 210)
                }
            }
            .scrollIndicators(.hidden)

            actionStack
        }
    }

    /// System close control. On iOS 26 the `.close` role draws the glass cross.
    @ToolbarContentBuilder
    private var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if #available(iOS 26.0, *) {
                Button(role: .close) {
                    dismiss()
                }
                .accessibilityIdentifier("xmark")
            } else {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("xmark")
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 20) {
            GlassHeroMark(assetName: OnboardingVisualAsset.proHeroMark, accent: accent)

            VStack(spacing: 10) {
                if entitlement.isEligibleForTrial {
                    Text("7 DAYS FREE")
                        .font(.caption.weight(.bold))
                        .kerning(0.8)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(accent.opacity(0.15))
                                .strokeBorder(accent.opacity(0.35), lineWidth: 0.75)
                        )
                }

                Text(headline)
                    .font(.title2.bold())
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Features

    private var featureCard: some View {
        ProFeatureCard(features: orderedFeatures, accent: accent, highlighted: context.feature)
    }

    /// The feature the user just experienced leads the list — the paywall should
    /// open on the thing they already know works.
    private var orderedFeatures: [ProFeature] {
        return [ProFeature.voice, ProFeature.messageImport]
//        guard let highlighted = context.feature else { return ProFeature.allCases }
//        return [highlighted] + ProFeature.allCases.filter { $0 != highlighted }
    }

    // MARK: - Plans

    private var planSelector: some View {
        VStack(spacing: 10) {
            ForEach(ProEntitlement.Plan.allCases) { plan in
                if let product = entitlement.product(for: plan) {
                    PlanOptionRow(
                        product: product,
                        plan: plan,
                        isSelected: selectedPlan == plan,
                        accent: accent,
                        monthlyEquivalent: plan == .yearly ? monthlyEquivalent(for: product) : nil,
                        savingsBadge: plan == .yearly ? savingsBadge : nil
                    ) {
                        selectedPlan = plan
                    }
                }
            }

            if entitlement.products.isEmpty {
                ProgressView()
                    .tint(accent)
                    .padding(.vertical, 24)
            }
        }
    }

    private func monthlyEquivalent(for product: Product) -> String? {
        let perMonth = product.price / 12
        return perMonth.formatted(product.priceFormatStyle) + "/mo"
    }

    /// Yearly saving against paying monthly for twelve months.
    private var savingsBadge: String? {
        guard let yearly = entitlement.product(for: .yearly),
              let monthly = entitlement.product(for: .monthly) else { return nil }
        let twelveMonths = monthly.price * 12
        guard twelveMonths > 0, yearly.price < twelveMonths else { return nil }
        let ratio = ((twelveMonths - yearly.price) / twelveMonths as NSDecimalNumber).doubleValue
        let percent = Int((ratio * 100).rounded())
        guard percent > 0 else { return nil }
        return "SAVE \(percent)%"
    }

    // MARK: - Actions

    private var actionStack: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if entitlement.purchaseInFlight {
                        ProgressView().tint(OnboardingTheme.background)
                    } else {
                        Text(ctaTitle)
                            .font(.headline)
                            .foregroundStyle(OnboardingTheme.background)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(accent))
            }
            .disabled(entitlement.products.isEmpty || entitlement.purchaseInFlight || isRestoring)
            .opacity(entitlement.products.isEmpty ? 0.5 : 1)
            .padding(.horizontal, 24)

            // Required by App Review, and the honest thing to show anyway.
            Text(disclosureText)
                .font(.caption2)
                .foregroundStyle(OnboardingTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            HStack(spacing: 16) {
                Button {
                    startRestore()
                } label: {
                    if isRestoring {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Restore")
                    }
                }
                .disabled(isRestoring || entitlement.purchaseInFlight)
                Link("Privacy", destination: privacyPolicyURL)
                Link("Terms", destination: termsURL)
                Button(dismissTitle) {
                    dismiss()
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(OnboardingTheme.textSecondary)
            .padding(.bottom, 28)
        }
        .background(
            LinearGradient(
                colors: [OnboardingTheme.background.opacity(0), OnboardingTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 260)
            .allowsHitTesting(false),
            alignment: .bottom
        )
    }

    private func purchase() async {
        errorMessage = nil
        showPendingNotice = false
        Analytics.capturePro(.purchaseStarted, analyticsProperties.merging(
            [Analytics.Key.plan: selectedPlan.analyticsName]
        ) { _, new in new })

        let wasEligibleForTrial = entitlement.isEligibleForTrial

        switch await entitlement.purchase(selectedPlan) {
        case .purchased:
            if wasEligibleForTrial {
                Analytics.capturePro(.trialStarted, [
                    Analytics.Key.plan: selectedPlan.analyticsName,
                    Analytics.Key.context: context.analyticsName
                ])
                ProTrialReminder.scheduleIfNeeded(trialEndsAt: entitlement.trialEndsAt)
            }
            Analytics.capturePro(.purchaseCompleted, [
                Analytics.Key.plan: selectedPlan.analyticsName,
                Analytics.Key.context: context.analyticsName
            ])
            dismiss()

        case .pending:
            showPendingNotice = true

        case .cancelled:
            break

        case .failed(let message):
            errorMessage = message
            Analytics.capturePro(.purchaseFailed, [
                Analytics.Key.plan: selectedPlan.analyticsName,
                Analytics.Key.context: context.analyticsName
            ])
        }
    }

    /// Flip `isRestoring` before the Task hops, otherwise a second tap on the
    /// same run loop can still fire another `AppStore.sync()`.
    private func startRestore() {
        guard !isRestoring, !entitlement.purchaseInFlight else { return }
        isRestoring = true
        Task {
            await restore()
            isRestoring = false
        }
    }

    private func restore() async {
        errorMessage = nil
        guard let restored = await entitlement.restorePurchases() else { return }
        Analytics.capturePro(.restoreCompleted, [Analytics.Key.granted: restored])
        if restored {
            dismiss()
        } else {
            errorMessage = "No previous Spendrift Pro purchase was found on this Apple Account."
        }
    }

    // MARK: - Copy

    private var headline: String {
        switch context {
        case .celebration(let feature):
            feature.celebrationHeadline
        case .quotaExhausted(let feature):
            "You're out of free \(feature.unitLabel(count: 2)) this month"
        case .settings:
            "Spendrift Pro"
        case .winback:
            "Welcome back"
        }
    }

    private var subtitle: String {
        switch context {
        case .celebration(let feature):
            "\(feature.displayName) is part of Pro. You have "
                + "\(AIQuotaStore.remaining(feature)) free "
                + "\(feature.unitLabel(count: AIQuotaStore.remaining(feature))) left this month — "
                + "start your trial to make it unlimited."
        case .quotaExhausted(let feature):
            "Your free \(feature.displayName.lowercased()) refills on \(resetDateText). "
                + "Pro removes the limit entirely."
        case .settings:
            "Unlimited voice capture, SMS auto-import."
        case .winback:
            "Your Pro features are paused. Resubscribe to pick up where you left off."
        }
    }

    private var resetDateText: String {
        AIQuotaStore.nextResetDate().formatted(.dateTime.day().month(.abbreviated))
    }

    private var ctaTitle: String {
        entitlement.isEligibleForTrial ? "Start 7-day free trial" : "Subscribe"
    }

    private var dismissTitle: String {
        switch context {
        case .celebration:    "Not now"
        case .quotaExhausted: "Maybe later"
        case .settings, .winback: "Close"
        }
    }

    private var disclosureText: String {
        guard let product = entitlement.product(for: selectedPlan) else {
            return "Cancel anytime in Settings."
        }
        let period = selectedPlan == .yearly ? "year" : "month"
        let lead = entitlement.isEligibleForTrial
            ? "7 days free, then \(product.displayPrice) per \(period)."
            : "\(product.displayPrice) per \(period)."
        return lead + " Renews automatically until cancelled. Cancel anytime in Settings."
    }

    private var analyticsProperties: [String: Any] {
        var properties: [String: Any] = [Analytics.Key.context: context.analyticsName]
        if let feature = context.feature {
            properties[Analytics.Key.feature] = feature.rawValue
            properties[Analytics.Key.remaining] = AIQuotaStore.remaining(feature)
        }
        return properties
    }
}

// MARK: - Plan row

private struct PlanOptionRow: View {
    let product: Product
    let plan: ProEntitlement.Plan
    let isSelected: Bool
    let accent: Color
    let monthlyEquivalent: String?
    let savingsBadge: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? accent : OnboardingTheme.textSecondary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan == .yearly ? "Yearly" : "Monthly")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.textPrimary)

                        if let savingsBadge {
                            Text(savingsBadge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(OnboardingTheme.background)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(accent))
                        }
                    }

                    if let monthlyEquivalent {
                        Text(monthlyEquivalent)
                            .font(.caption)
                            .foregroundStyle(OnboardingTheme.textSecondary)
                    }
                }

                Spacer(minLength: 8)

                Text(product.displayPrice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.textPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(OnboardingTheme.card)
                    .strokeBorder(
                        isSelected ? accent.opacity(0.7) : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Analytics labels

extension ProEntitlement.Plan {
    var analyticsName: String {
        switch self {
        case .yearly:  "yearly"
        case .monthly: "monthly"
        }
    }
}

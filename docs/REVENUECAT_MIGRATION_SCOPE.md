# Spendrift Pro - migrating the StoreKit 2 implementation to RevenueCat

**Status:** scoped on September 9, 2026. No implementation has started.
**Companion docs:** [`PRO_PRICING.md`](PRO_PRICING.md) (what Pro costs), [`PRO_TRIAL_PLACEMENT.md`](PRO_TRIAL_PLACEMENT.md) (when the trial is offered).
Neither of those changes as a result of this work.

This document is the agreed scope for replacing the direct StoreKit 2 code behind Spendrift Pro with the RevenueCat SDK.
It records what exists today, what the end state looks like, which decisions are still open, and how the work is split into small independently shippable steps.
Each step will be designed in detail and agreed before it is implemented.

## 1. Goal and non-goals

### Goal

Make RevenueCat the source of truth for whether a user has Spendrift Pro, while keeping every user-facing behaviour of the current implementation intact: the same two products, the same 7-day trial, the same paywall, the same free-tier quotas, the same celebration and quota-wall placements, the same India-specific copy.

A user who is subscribed before the migration must still be subscribed after it, without doing anything.

### Why RevenueCat rather than the current code

The current implementation verifies entitlements on the device only.
That was the right call to ship Pro quickly, but it leaves gaps that grow with every subscriber:

- There is no server-side record of who is subscribed, so the backend cannot enforce quotas or the fair-use ceiling that `PRO_PRICING.md` flags as a pre-launch risk.
  `spendrift-backend/docs/BACKEND_ROADMAP.md` Phase 4 assumes exactly this server-side record.
- Refunds, billing retries, grace periods and family-sharing edge cases each need bespoke handling in `ProEntitlement.refreshEntitlement`.
- There is no revenue, trial-conversion or churn dashboard beyond what can be reconstructed from PostHog events.
- App Store Server Notifications are not consumed anywhere, so a refund only shows up when the user next opens the app.

RevenueCat provides receipt validation, an entitlement record per customer, App Store Server Notification handling, charts, and webhooks for a later backend integration.
It is free up to $2,500 of monthly tracked revenue and charges 1% of tracked revenue above that.

### Non-goals (explicitly out of scope for this migration)

- Changing prices, products, the subscription group, trial length, or quota sizes.
- Replacing the custom `ProPaywallView` with RevenueCat's hosted Paywalls or Customer Center.
- Backend enforcement of Pro via RevenueCat webhooks or REST API.
  This is the natural next project once RevenueCat holds the entitlement record, and is listed in section 9.
- User accounts or sign-in.
  Spendrift has no accounts and PostHog deliberately never calls `identify()`; RevenueCat will run with anonymous app user IDs.
- The fair-use ceiling for Pro users described in `PRO_PRICING.md`.
- Widget or Share Extension awareness of Pro.
  Neither target references any Pro type today (verified by grep), so nothing needs to change there.

## 2. Inventory of the current implementation

All Pro code landed in a single commit, `374b508 feat: Spendrift Pro`, in the `Spendrift/` repository.
Everything below lives under `Spendrift/Spendrift/` unless stated otherwise.

### 2.1 Files that call StoreKit directly (must change)

| File | StoreKit API used | What it does | Migration impact |
|---|---|---|---|
| `Services/Pro/ProEntitlement.swift` | `Product.products(for:)`, `Transaction.updates`, `Transaction.currentEntitlements`, `Transaction.all`, `Product.purchase()`, `AppStore.sync()`, `SubscriptionInfo.isEligibleForIntroOffer`, `StoreKitError` | The main-actor source of truth. Loads the two products, listens for transaction updates, collapses entitlements into `Status`, runs purchases and restores, and writes through to `ProEntitlementCache`. | **High.** The internals are rewritten on top of RevenueCat. The public surface (`status`, `isPro`, `isInTrial`, `trialEndsAt`, `isEligibleForTrial`, `purchaseInFlight`, `isLoadingProducts`, `purchase(_:)`, `restorePurchases()`, `start()`, `loadProducts()`) is kept so that views change as little as possible. |
| `Views/Pro/ProPaywallView.swift` | `import StoreKit`; uses `Product` for `price`, `displayPrice`, `priceFormatStyle` | Plan rows, yearly-as-monthly equivalent, savings badge, disclosure line, purchase and restore actions. | **Medium.** `Product` becomes RevenueCat's `StoreProduct` (reached through a `Package`). Price arithmetic for the savings badge and monthly equivalent moves to `StoreProduct.price` (a `Decimal`) and `priceFormatter`. Copy and layout are unchanged. |
| `Views/Pro/ProStatusSettingsView.swift` | `import StoreKit` for the SwiftUI `.manageSubscriptionsSheet` modifier | Settings rows: active plan or trial countdown when subscribed; per-feature remaining quota, upgrade row and Restore row when not. | **Low.** The modifier is part of SwiftUI's StoreKit integration and can stay, or be swapped for `Purchases.shared.showManageSubscriptions()`. See decision D6. |

### 2.2 Files that depend on Pro state but not on StoreKit (unchanged)

| File | Role | Why it is unaffected |
|---|---|---|
| `Services/Pro/ProEntitlementCache.swift` (inside `ProEntitlement.swift`) | App Group `UserDefaults` mirror of the last known entitlement, with an expiry check. Read by `ProGate` and by `MessageInboxSyncService` from headless App Intent runs. | Its shape (`isPro`, `expiresAt`) is exactly what RevenueCat's `EntitlementInfo` exposes. It stays as the cross-process bridge and the offline / cold-launch guard. Only the writer changes. |
| `Services/Pro/ProGate.swift` | The single decision point for "may this AI call happen". Reads only `ProEntitlementCache.isPro` and `AIQuotaStore`. | No StoreKit. |
| `Services/Pro/AIQuotaStore.swift` | Per-feature monthly free counters in the App Group suite. | No StoreKit. |
| `Services/Pro/ProFeature.swift` | The four gated features and their quotas and copy. | No StoreKit. |
| `Services/Pro/ProTrialReminder.swift` | Local notification two days before trial end. Takes `trialEndsAt` as input. | Input keeps coming from `ProEntitlement.trialEndsAt`. |
| `Views/Pro/ProPaywallPresenter.swift` | `proPaywall(_:)` modifier and `ProAccess.attempt`. | No StoreKit. |
| `SpendriftApp.swift` | Calls `entitlement.start()` in the root `.task`, watches `entitlement.status` to refresh the trial reminder, queues paywalls, and sets `ProEntitlementCache.isPro = true` under `-UITesting`. | Gains one line: SDK configuration in `init()`. Everything else is unchanged. |
| `Services/AI/VoiceTransactionService.swift`, `BankStatementService.swift`, `Receipt/ReceiptTransactionService.swift`, `MessageInbox/MessageInboxSyncService.swift`, `Voice/VoiceTransactionCreator.swift`, `Receipt/ReceiptTransactionCreator.swift`, `Views/Transactions/StatementImportView.swift` | Call `ProGate.isAllowed`, `recordUsage`, `announceMomentIfNeeded`, `reportBlocked`. | Go through `ProGate` only. |
| `ContentView.swift`, `Views/Transactions/TransactionsView.swift`, `Views/Settings/SettingsView.swift`, `Views/Settings/CaptureSettingsView.swift` | Nine `ProAccess.attempt` call sites and four `.proPaywall` attachments. | Go through `ProAccess` and `PaywallContext` only. |
| `Views/Transactions/MessageInboxImportBannerView.swift` | Reports blocked SMS drains in place. | Consumes `blockedCount` from the sync service. |
| `Services/Analytics/Analytics.swift` | Nine Pro events (`paywall_viewed`, `paywall_dismissed`, `purchase_started`, `trial_started`, `purchase_completed`, `purchase_failed`, `restore_completed`, `quota_exhausted`, `pro_feature_blocked`) and `capturePro` which stamps `days_since_install`. | Event names and properties are kept verbatim so existing PostHog funnels keep working. |
| `Utilities/AppStoreReviewRequest.swift` | `SKStoreReviewController` review prompts. | Imports StoreKit but has nothing to do with purchases. Untouched. |
| `SpendriftTests/ProGateTests.swift` | 15 tests covering quota arithmetic, gate decisions, cache expiry, pitch bookkeeping. Uses only `ProEntitlementCache`, `ProGate`, `AIQuotaStore`. | Keeps passing without modification. New tests are added, not substituted. |

### 2.3 Configuration and tooling that changes

| Item | Today | After |
|---|---|---|
| `Spendrift/Products.storekit` | Local StoreKit configuration: subscription group `21561001` "Spendrift Pro", products `com.ronakpunase.Spendrift.pro.yearly` (₹999, P1Y) and `com.ronakpunase.Spendrift.pro.monthly` (₹149, P1M), each with a free P1W introductory offer, storefront IND. | Kept for local Xcode runs. Its StoreKit testing certificate is uploaded to RevenueCat so sandbox receipts from the simulator validate. |
| `Spendrift.xcodeproj/xcshareddata/xcschemes/MyMoney.xcscheme` | References `Products.storekit` in the launch action. | Unchanged. |
| `project.pbxproj` SPM packages | posthog-ios 3.60.0, sentry-cocoa 8.58.3, DebugSwift 1.19.0. | Adds `https://github.com/RevenueCat/purchases-ios-spm.git`, product `RevenueCat`, linked to the **Spendrift** app target only. Not the widget, not the share extension, not the test targets. |
| `Configuration/DevSecrets.xcconfig`, `Configuration/ProdSecrets.xcconfig` (gitignored) | Backend URL, backend client token, PostHog key, Sentry DSN. | Adds `SPENDRIFT_REVENUECAT_API_KEY`. The RevenueCat public Apple API key is designed to ship in the binary, but it still follows the same xcconfig path as the PostHog key so Debug and Release can point at different RevenueCat projects if wanted. |
| `Info.plist` | `$(SPENDRIFT_*)` keys. | Adds `SpendriftRevenueCatAPIKey = $(SPENDRIFT_REVENUECAT_API_KEY)`. |
| `Services/AppSecrets.swift` | Accessors for the four secrets. | Adds `revenueCatAPIKey`. |
| `ci_scripts/ci_post_clone.sh` | Writes `ProdSecrets.xcconfig` from Xcode Cloud environment variables. | Writes the new variable too. The variable must be added in Xcode Cloud before the first CI build of the branch. |
| `Spendrift-knowledge-base.md` (workspace root), `docs/FEATURES_AND_MONETIZATION.md` line 206 | State "StoreKit 2, verified client-side" and, in the knowledge base, "no StoreKit paywall in code" (already stale). | Updated in the final step. |

### 2.4 Process model (important for where the SDK is configured)

- `VoiceExpenseIntent` has `openAppWhenRun = true`, so voice always runs inside the foreground app.
- `LogTransactionMessageIntent` has `openAppWhenRun = false` and only writes SMS bodies to the inbox store.
  It never evaluates Pro.
- The SMS drain (`MessageInboxSyncService`) and every other gate check run inside the **main app process**, either foreground or launched in the background by the system for an App Intent declared in the app target.
  `SpendriftApp.init()` runs in both cases, so configuring the SDK there is sufficient.
- The widget and share extension targets contain no Pro code.
  RevenueCat's extension guidance (shared `UserDefaults` suite, read-only) is therefore **not needed** now.
  `ProEntitlementCache` already solves the cross-process read.

## 3. Target architecture

### 3.1 RevenueCat dashboard model

| RevenueCat concept | Value | Maps to |
|---|---|---|
| Project / iOS app | Spendrift, bundle `com.ronakpunase.Spendrift` | one project, one Apple app |
| Products | `com.ronakpunase.Spendrift.pro.yearly`, `com.ronakpunase.Spendrift.pro.monthly` | the existing App Store Connect products; IDs never change |
| Entitlement | `pro` | `ProEntitlement.isPro` |
| Offering | `default` (marked current) | the paywall's plan list |
| Packages | `$rc_annual` -> yearly product, `$rc_monthly` -> monthly product | `ProEntitlement.Plan.yearly` / `.monthly` |

Keeping `ProEntitlement.Plan` as an enum over the two product IDs means the yearly-first ordering, analytics labels (`plan: yearly | monthly`) and `selectedPlan` state in the paywall stay exactly as they are.
Packages are looked up by product ID, not by position, so a re-ordered offering in the dashboard cannot reorder the UI.

### 3.2 SDK configuration

Configured once, in `SpendriftApp.init()`, before `Analytics.bootstrap()` returns control and before any view can call `ProEntitlement.shared`:

- API key from `AppSecrets.revenueCatAPIKey`.
- StoreKit 2, which is the SDK v5 default.
  This requires the App Store Connect In-App Purchase Key (`.p8`) to be uploaded to RevenueCat; without it purchases fail to record.
- `purchasesAreCompletedBy: .revenueCat` in the end state.
  Whether an intermediate observer step (`.myApp`) is used is decision D1.
- Anonymous app user ID (decision D2).
- Default `UserDefaults` for the SDK's own cache (decision D3).
- Configuration is skipped entirely under `-UITesting`, where `ProEntitlementCache` is already forced to Pro and network traffic would only add flakiness.

### 3.3 Entitlement flow

`ProEntitlement.start()` subscribes to `Purchases.shared.customerInfoStream` instead of `Transaction.updates`, and calls `Purchases.shared.customerInfo()` for the first read instead of iterating `Transaction.currentEntitlements`.
`CustomerInfo` is reduced to the existing `Status` enum by a **pure, testable function**:

| `CustomerInfo` observation | `Status` |
|---|---|
| `entitlements["pro"]` active and `periodType == .trial` | `.trial(endsAt: expirationDate)` |
| `entitlements["pro"]` active and `periodType` is `.normal` or `.intro` | `.subscribed(expiresAt: expirationDate)` |
| not active, but `allPurchasedProductIdentifiers` contains either plan | `.lapsed` |
| not active, nothing ever purchased | `.free` |
| SDK has not answered yet | `.unknown` (falls back to `ProEntitlementCache`, as today) |

`allPurchasedProductIdentifiers` replaces the `Transaction.all` scan that currently detects the win-back audience.
After every reduction, `ProEntitlementCache.update(isPro:expiresAt:)` is called exactly as today, so `ProGate` and the headless SMS drain need no changes.

Grace periods and billing retry appear as an active entitlement with `willRenew` and a future `expirationDate`, so a subscriber in billing retry keeps Pro rather than dropping to free, which is the behaviour Apple recommends and the current code approximates by trusting `expirationDate`.

### 3.4 Products, prices and trial eligibility

- `loadProducts()` fetches `Purchases.shared.offerings()` and stores the current offering's packages keyed by `Plan`.
- The paywall reads `package.storeProduct.localizedPriceString` for display and `storeProduct.price` (a `Decimal`) for the savings badge and monthly-equivalent math, formatted with `storeProduct.priceFormatter`.
- `isEligibleForTrial` comes from `Purchases.shared.checkTrialOrIntroDiscountEligibility(product:)`.
  An `.unknown` result must map to a default; today the default is `true`.
  This is decision D5.
- The introductory offer shown in copy ("7 DAYS FREE") continues to be hard-coded in copy as today.
  Reading it from `storeProduct.introductoryDiscount.subscriptionPeriod` is a small optional improvement noted in section 9.

### 3.5 Purchase and restore

- `purchase(_ plan:)` calls `Purchases.shared.purchase(package:)`.
  The result carries `userCancelled` and the updated `CustomerInfo`, which is reduced to `Status` immediately so the paywall dismisses on the same tick.
- The four existing `PurchaseOutcome` cases are preserved:
  - `.purchased` on success;
  - `.cancelled` when `userCancelled` is true or `ErrorCode.purchaseCancelledError` is thrown;
  - `.pending` when `ErrorCode.paymentPendingError` is thrown (Ask to Buy, or a UPI Autopay mandate awaiting bank confirmation, both real cases in India);
  - `.failed(message:)` for everything else.
- The India-specific failure copy in `ProEntitlement.message(for:)` is preserved and re-keyed from `StoreKitError` cases to RevenueCat `ErrorCode` cases (`networkError`, `storeProblemError`, `purchaseNotAllowedError`, `productNotAvailableForPurchaseError`).
- `restorePurchases()` calls `Purchases.shared.restorePurchases()`.
  RevenueCat is explicit that this must only run from a user tap because it may show an Apple ID sign-in prompt.
  Both existing call sites (paywall "Restore", Settings "Restore purchases") are user taps, so no launch-time restore exists to remove.
- Transaction finishing is done by the SDK (`.revenueCat` mode), so the manual `transaction.finish()` calls disappear.

### 3.6 Existing subscribers

If Pro is live on the App Store before the migration ships (open question Q1), there will be devices where `ProEntitlementCache.isPro` is true but RevenueCat has never seen the receipt.
RevenueCat's guidance is a **one-time, conditional** `syncPurchases()`: only when the old system says subscribed and `CustomerInfo` has no active `pro` entitlement, and never on every launch, because repeated syncs add latency and can alias unrelated customers.
The scope includes a `didSyncLegacyEntitlement` flag in the App Group suite to guarantee the once-only rule.
If Q1 confirms there are no live subscribers, this step is still cheap to keep but becomes a no-op in practice.

## 4. Non-code setup (RevenueCat dashboard and App Store Connect)

These happen before any Swift changes and are owned by Ronak, since they need App Store Connect and RevenueCat account access.

1. Create the RevenueCat project and iOS app for bundle `com.ronakpunase.Spendrift`; note the public Apple API key.
2. In App Store Connect, under Users and Access > Integrations > In-App Purchase, generate an In-App Purchase Key.
   Download the `.p8` (only possible once) and upload it with the Key ID and Issuer ID to RevenueCat.
   StoreKit 2 in the SDK does not work without it.
3. Import the two products into RevenueCat, create the `pro` entitlement, attach both products, create the `default` offering with `$rc_annual` and `$rc_monthly` packages, and mark it current.
4. Paste RevenueCat's App Store Server Notifications URL into App Store Connect for **both** Production and Sandbox, as Version 2 notifications.
   Apple allows one URL per environment; nothing is configured there today, so there is no conflict.
5. Export the StoreKit testing certificate from Xcode for `Products.storekit` and upload it to RevenueCat so local simulator runs validate.
6. Leave restore behaviour at the default, "Transfer to new App User ID".
   With anonymous IDs this merges a reinstalled device back onto its purchases.
7. Have at least one App Store sandbox tester account ready on a physical device for the verification steps below.
8. Add `SPENDRIFT_REVENUECAT_API_KEY` to the local `DevSecrets.xcconfig` and `ProdSecrets.xcconfig`, and to Xcode Cloud's environment variables.

## 5. Phased plan

Each phase is a separate branch and, where it touches Swift, a separate compile-verified change agreed beforehand.
Verification is by compilation only; no simulator-based tests or builds are run from this environment.
Sandbox purchase testing is manual, on a device, and is called out per phase.

### Phase 0 - Dashboard and App Store Connect setup

Section 4 in full.
No code.
**Exit:** RevenueCat shows both products under the `pro` entitlement in a current offering, the In-App Purchase Key and StoreKit certificate are accepted, server notification URLs are saved in App Store Connect.

### Phase 1 - Add the SDK without changing behaviour

- Add the `purchases-ios-spm` package, pinned "Up to Next Major from 5.x" at whatever the latest 5.x is on the day (the changelog currently shows 5.88.0).
- Plumb the API key through xcconfig, `Info.plist`, `AppSecrets`, and `ci_post_clone.sh`.
- Configure `Purchases` in `SpendriftApp.init()`, skipped under `-UITesting`.
- If D1 chooses observer-first: configure with `.myApp` + `.storeKit2`, and add a single `Purchases.shared.recordPurchase(_:)` call after the existing `product.purchase()` so RevenueCat starts seeing sandbox purchases while StoreKit code stays authoritative.
- Remove the `private typealias StoreTransaction = StoreKit.Transaction` in `ProEntitlement.swift`, because RevenueCat exports a public `StoreTransaction` type and the two names would clash on import.
  This is the only identifier collision found; the project has no types named `Package`, `Offering`, `Configuration`, `StoreProduct`, `CustomerInfo` or `Purchases`.

**Exit:** app compiles and behaves exactly as before; RevenueCat dashboard shows a sandbox customer after a test purchase on device.

### Phase 2 - Move `ProEntitlement` onto RevenueCat

- Rewrite the internals as described in section 3.3 to 3.5, keeping the public surface.
- Introduce the pure `Status` reducer and unit-test it in `SpendriftTests` with hand-built inputs (active flag, period type, expiration date, purchased product IDs), so no RevenueCat mocking is required.
- Switch configuration to `.revenueCat` and delete manual `finish()` calls.
- Keep `products` exposed to views as a thin wrapper so Phase 3 can be reviewed separately.

**Exit:** compiles; `ProGateTests` still pass unchanged; new reducer tests pass; on device, purchase, cancel, pending and restore each land in the correct `Status`.

### Phase 3 - Paywall and Settings view types

- `ProPaywallView` and `PlanOptionRow` take a `Package` (or a small view-model struct built from it) instead of `Product`.
- Savings badge and monthly equivalent are recomputed from `Decimal` prices and `priceFormatter`; assert the same strings appear for ₹999/₹149.
- `import StoreKit` is removed from the two Pro views (subject to D6).

**Exit:** compiles; the paywall renders the same prices, badges and disclosure line as before against `Products.storekit`.

### Phase 4 - Legacy subscriber sync and hardening

- Add the once-only `syncPurchases()` path from section 3.6.
- Sandbox script on device: fresh install and subscribe; kill and relaunch offline and confirm no paywall flash; delete and reinstall and confirm entitlement returns (via automatic sync or Restore); let a sandbox trial expire and confirm `.lapsed` and the win-back paywall; cancel and confirm `.free` copy in Settings.
- Sentry: purchase failures are already logged through `Diagnostics`; confirm the new error codes carry the same tags.

**Exit:** all scenarios above observed on device; no residual `import StoreKit` outside `AppStoreReviewRequest.swift` and, if kept, the manage-subscriptions modifier.

### Phase 5 - Documentation and privacy

- Update `docs/FEATURES_AND_MONETIZATION.md` and the workspace `Spendrift-knowledge-base.md` to describe the RevenueCat-backed entitlement.
- Update the App Store privacy nutrition label if the RevenueCat SDK's declared data types (purchase history, device identifiers) are not already covered.
  The app has no `PrivacyInfo.xcprivacy` of its own today; the SDK ships one, but App Store Connect answers are a manual step.
- The public privacy policy (`spendrift-frontend/PrivacyPolicy.txt`) currently describes only AI providers and does not mention purchases, analytics, or crash reporting.
  Adding a subscription-processing paragraph that names the purchase-validation processor is recommended in the same pass.
  This is a frontend repository change and can be a separate small PR.

## 6. Decisions to make before Phase 1

Each has a recommendation; none is made yet.

**D1. Observer-first (`.myApp`) or straight to `.revenueCat`?**
Recommendation: observer-first.
The riskiest part of the migration is dashboard configuration ("purchases will fail if the key is not configured"), and observer mode validates it with real sandbox traffic while the proven StoreKit code stays in charge.
Cost is one extra `recordPurchase` line that is deleted in Phase 2.
Alternative: skip it and rely on Phase 2 sandbox testing; fewer steps, but the first time RevenueCat is exercised is also the first time it is authoritative.

**D2. Anonymous app user ID or a custom ID?**
Recommendation: anonymous.
Spendrift has no accounts, is privacy-first, and PostHog is configured with `personProfiles = .identifiedOnly` and never calls `identify()`.
A custom ID would only be justified for a future backend gate, and RevenueCat's REST API can look customers up by the anonymous ID that the app already has, so nothing is lost by deferring.

**D3. Which `UserDefaults` does the SDK cache into?**
Recommendation: the default (`.standard`).
Passing the App Group suite would let extensions read `CustomerInfo` directly, but no extension needs it, `ProEntitlementCache` already bridges processes, and the SDK stores the anonymous app user ID in whichever defaults it is given, so changing the suite later effectively creates a new anonymous customer.
Pick once and keep it.

**D4. Keep the custom paywall or adopt RevenueCat Paywalls?**
Recommendation: keep the custom paywall.
It is designed, its four contexts and copy are tied to `PRO_TRIAL_PLACEMENT.md`, and every PostHog event is wired to it.
RevenueCat Paywalls can be revisited later for A/B tests without blocking this migration.

**D5. What does `.unknown` trial eligibility mean?**
Recommendation: treat as eligible, matching today's `isEligibleForTrial = true` default, so the CTA reads "Start 7-day free trial" until proven otherwise.
Apple applies the offer only when the account is actually eligible, so the risk is a mislabelled button, not a wrong charge.
Alternative: treat as not eligible and show "Subscribe", which under-sells the trial to first-time users on slow networks.

**D6. Manage subscription: SwiftUI `.manageSubscriptionsSheet` or `Purchases.shared.showManageSubscriptions()`?**
Recommendation: keep the SwiftUI modifier.
It works, it needs only `import StoreKit` in one Settings file, and it does not depend on RevenueCat being reachable.

**D7. SDK version pin.**
Recommendation: "Up to Next Major from" the latest 5.x on the day Phase 1 starts, mirroring how PostHog and Sentry are pinned.
Verify the version against the GitHub releases page at that time; the fetch performed for this scope surfaced 5.88.0 as newest.

**D8. Analytics.**
Recommendation: leave the nine PostHog events as they are.
RevenueCat's charts become the source for revenue and trial-conversion numbers; PostHog remains the source for the placement funnel.
Wiring RevenueCat's PostHog integration would require a shared user ID and is out of scope per D2.

## 7. Open questions for Ronak

**Q1. Is a build containing Pro (`374b508`) already live on the App Store, and are there real subscribers?**
The knowledge base still says the live app has no paywall, and `PRO_PRICING.md` says US and EU prices are yet to be set in App Store Connect.
If there are no live subscribers, Phase 4's legacy sync is a safety net rather than a requirement and the whole migration can be validated purely in sandbox.

**Q2. Do the RevenueCat account and App Store Connect access already exist, or does Phase 0 start from account creation?**

**Q3. Should Debug builds point at a separate RevenueCat project (or a sandbox-only app) so test purchases never touch production charts?**
RevenueCat separates sandbox and production data within one project, so a single project is normally sufficient; a separate project is only needed if the dashboard must stay clean of test customers.

## 8. Risks and failure modes

| Risk | Effect | Mitigation |
|---|---|---|
| In-App Purchase Key missing or wrong bundle ID in RevenueCat | Every purchase fails at validation; users are charged by Apple but not granted Pro. | Phase 0 exit criteria; observer-mode sandbox purchase in Phase 1 before RevenueCat is authoritative. |
| Cold launch before `CustomerInfo` arrives | Paywall flash or blocked AI call for a subscriber. | `.unknown` status keeps falling back to `ProEntitlementCache`, exactly as today. |
| Offline launch | Same as above. | SDK caches `CustomerInfo` on device; `ProEntitlementCache` adds the expiry guard. |
| Pending purchase (UPI Autopay mandate, Ask to Buy) | Paywall would show a generic failure. | Map `paymentPendingError` to `.pending` so the existing "waiting on approval" notice shows; entitlement arrives later via `customerInfoStream`. |
| Reinstall wipes the anonymous app user ID | New anonymous customer without entitlement. | Default transfer behaviour moves purchases to the restoring ID; Restore button exists in two places; Phase 4 tests this path explicitly. |
| `StoreTransaction` name clash | Compile error on first import. | Removed in Phase 1. |
| `-UITesting` runs hit the network | Flaky UI tests. | SDK configuration skipped under the flag; `ProEntitlementCache` remains forced to Pro. |
| Programmatic `restorePurchases` or repeated `syncPurchases` | Apple ID prompts on launch; aliased customers. | Restore only from taps; sync once behind a persistent flag. |
| Privacy positioning | RevenueCat receives receipt data and device identifiers that never left the device before. | Phase 5 nutrition-label and privacy-policy updates; note that no transaction ledger data is involved. |
| Cost | 1% of tracked revenue above $2,500 per month. | Acceptable; noted for `PRO_PRICING.md` margin math. |

## 9. Follow-ups enabled by this migration (not in scope)

- Backend enforcement of quotas and the Pro fair-use ceiling using RevenueCat webhooks or the REST API, per `BACKEND_ROADMAP.md` Phase 4.
- Reading the introductory offer period from `StoreProduct` instead of hard-coding "7 days" in copy.
- RevenueCat Paywalls for A/B testing the celebration sheet.
- RevenueCat Customer Center to replace the manage-subscription and restore rows.
- Adding `pro` to `Diagnostics.Feature` so purchase failures are filterable in Sentry independently of `app`.

## 10. Definition of done

- No file outside `AppStoreReviewRequest.swift` and (if D6 stands) `ProStatusSettingsView.swift` imports StoreKit.
- `ProEntitlement`'s public surface is unchanged and every view compiles without behavioural edits beyond the `Product` to `Package` type change.
- `ProGateTests` pass unchanged; the `Status` reducer has its own tests.
- All Phase 4 sandbox scenarios have been observed on a device.
- RevenueCat dashboard shows the sandbox customer lifecycle (trial, conversion, expiry, restore) for the test account.
- `FEATURES_AND_MONETIZATION.md`, the knowledge base, and the privacy documents reflect the new setup.

## Sources consulted

- [RevenueCat - iOS SDK installation](https://www.revenuecat.com/docs/getting-started/installation/ios) - SPM URL and version rule
- [RevenueCat - Configuring the SDK](https://www.revenuecat.com/docs/getting-started/configuring-sdk) - configure at launch, anonymous IDs, `userDefaults` override
- [RevenueCat - iOS 4.x to 5.x migration](https://www.revenuecat.com/docs/sdk-guides/ios-native-4x-to-5x-migration) - StoreKit 2 default, In-App Purchase Key requirement, `PurchasesAreCompletedBy`
- [RevenueCat - In-App Purchase Key configuration](https://www.revenuecat.com/docs/in-app-purchase-key-configuration)
- [RevenueCat - Finishing transactions](https://www.revenuecat.com/docs/migrating-to-revenuecat/sdk-or-not/finishing-transactions) - `.myApp` vs `.revenueCat`
- [RevenueCat - Migrating existing subscriptions](https://www.revenuecat.com/docs/migrating-to-revenuecat/migrating-existing-subscriptions) - conditional one-time `syncPurchases`
- [RevenueCat - Restoring purchases](https://www.revenuecat.com/docs/getting-started/restoring-purchases) and [Restore behavior](https://www.revenuecat.com/docs/projects/restore-behavior)
- [RevenueCat - CustomerInfo](https://www.revenuecat.com/docs/customers/customer-info) - caching, offline entitlements, `customerInfoStream`, `EntitlementInfo` fields
- [RevenueCat - Apple server notifications](https://www.revenuecat.com/docs/platform-resources/server-notifications/apple-server-notifications)
- [RevenueCat - Apple sandbox and StoreKit configuration testing](https://www.revenuecat.com/docs/test-and-launch/sandbox/apple-app-store)
- [RevenueCat - iOS app extensions](https://www.revenuecat.com/docs/getting-started/configuring-sdk/ios-app-extensions)
- [RevenueCat - Pricing](https://www.revenuecat.com/pricing)
- [purchases-ios CHANGELOG](https://github.com/RevenueCat/purchases-ios/blob/main/CHANGELOG.md)



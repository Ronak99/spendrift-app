> **Note (2026):** Spendrift no longer mirrors ledger data to iCloud CloudKit. The seeding flow described below was later simplified to local-only seeding when onboarding starts. CloudKit-specific wait/reconcile steps are historical.
# When “Add Transaction” Shows Nothing: Fixing Default Data Seeding in Spendrift

*How scattered SwiftData seeding, CloudKit sync timing, and SwiftUI lifecycle quirks combined into a first-run bug — and how we fixed it with one orchestrator.*

---

## What is Spendrift?

**Spendrift** is a personal finance app for iOS, built with SwiftUI and SwiftData. It helps you track expenses and income across multiple accounts, organize spending with categories, and log transactions quickly — by typing, speaking, or importing statements.

A few things that matter for this story:

- **Local-first.** Your data lives on-device in a shared SwiftData store (the main app, widgets, and Siri Shortcuts all read the same App Group container).
- **Onboarding for new users.** First-time users see a short three-page carousel (welcome, Siri & Shortcuts, get started). When they finish, they land on an empty Transactions tab with a prominent **“Add Transaction”** call to action.
- **Starter data for brand-new users.** If someone has never used Spendrift before, we seed a default **“Savings”** account (balance ₹100) and a curated set of expense/income categories so they can log their first transaction immediately — no manual setup required.

That last point sounds simple. It wasn’t.

---

## The expected experience

Here is what we wanted — and what users reasonably expected:

1. User installs Spendrift and sees onboarding.
2. **While onboarding is on screen**, the app quietly prepares their starter data in the background.
3. User taps **Get Started**, dismisses onboarding, and sees the empty Transactions screen.
4. User taps **Add Transaction**.
5. The transaction sheet opens with a **default account** and **default categories** already available in the pickers.

No tab switching. No waiting. No “why is everything empty?”

The empty-state CTA is the first real action most users take. If categories and accounts aren’t there, the app feels broken before it has even started.

---

## What users actually saw

In practice, many first-time users hit **Add Transaction** and found:

- An empty or incomplete **account** picker
- An empty or incomplete **category** picker

If they navigated to the **Categories** tab and came back, categories would suddenly appear. Accounts might show up on their own timeline, or only after visiting Accounts. The experience was inconsistent and confusing.

From the outside it looked like a UI bug. From the inside it was a **data initialization architecture** problem.

---

## Root cause: seeding was scattered everywhere

We had **two different kinds of starter data** (accounts and categories) being seeded from **three different places**, with **different timing rules**.

### Categories — seeded in the wrong place

Default categories were inserted from:

| Location | Trigger |
|----------|---------|
| `CategoriesView.onAppear` | User opens the Categories tab |
| `ContentView.onAppear` | Only when `-UITesting` launch argument is set |
| `ScreenshotDemoData` | App Store screenshot / demo builds |

The production path that mattered most was `CategoriesView.onAppear`. Categories simply **did not exist** until the user visited that tab.

SwiftData’s `@Query` is reactive — views update when the store changes. But if nothing inserts categories until CategoriesView appears, the Transactions tab and the Add Transaction sheet have nothing to show.

### Accounts — seeded somewhere else entirely

Accounts were handled by a separate type, `DefaultAccountSeeder`, launched from `ContentView`’s `.task` on **every app launch**:

```swift
// ContentView.swift (before)
.task {
    await DefaultAccountSeeder.seedIfNeeded(modelContext: modelContext)
}
```

That seeder was smarter about CloudKit: it waited for CloudKit’s initial import to finish (with a 10-second timeout) before deciding whether to insert the default Savings account. But it ran on launch, **not** during onboarding, and it had **no relationship** to category seeding.

### Why this felt so buggy

Put the pieces together:

1. **Different triggers** — accounts on launch, categories on tab visit.
2. **Different timing** — account seeding waited for CloudKit; category seeding did not always follow the same rules.
3. **Race conditions** — a user could finish onboarding and tap Add Transaction before either seeder had done its job, or before only one of them had.
4. **Navigation as a hidden dependency** — the app accidentally required users to visit Categories (and sometimes Accounts) to “wake up” their data.

The bug wasn’t that seeding failed. It was that seeding was **fragmented**, **order-sensitive**, and **tied to the wrong UI lifecycle hooks**.

---

## The CloudKit complication

Spendrift syncs to iCloud. That adds a constraint every reinstall and multi-device user hits:

> **Don’t seed defaults until you know CloudKit isn’t about to deliver existing data.**

If someone deletes the app and reinstalls, their accounts and categories should **restore from iCloud**, not be replaced by fresh defaults. If we seed too eagerly, we risk duplicates or overwriting synced state.

The old `DefaultAccountSeeder` already solved part of this by listening for `NSPersistentCloudKitContainer.eventChangedNotification` and waiting for a finished `.import` event (with a timeout fallback for offline / fresh accounts).

Categories, meanwhile, used a mix of “is the local store empty?” checks and iCloud Key-Value Store flags — but the **trigger** (Categories tab `onAppear`) was still wrong even when the guard logic was reasonable.

We needed **one flow** that:

1. Waits for CloudKit’s initial import when necessary
2. Checks what actually exists in the store **after** sync
3. Seeds only what is still missing
4. Runs at the right moment in the user journey — onboarding start — not when a particular tab happens to appear

---

## The fix: `DefaultDataSeeder`

We replaced the scattered seeders with a single orchestrator: `DefaultDataSeeder`.

### Design principles

1. **Single source of truth** — one function owns account + category seeding.
2. **Onboarding is the trigger** — seeding starts when onboarding begins, not on arbitrary view appearances.
3. **Silent and background** — no blocking UI; the user swipes through onboarding while data prepares.
4. **CloudKit-aware** — wait for import, then decide.
5. **Idempotent** — safe to call more than once; only inserts when the store is still empty.
6. **Reactive by default** — writes go into the shared `ModelContext`, so every `@Query`-backed view updates automatically.

### The algorithm

```swift
@MainActor
static func seedIfNeeded(modelContext: ModelContext) async {
    // Legacy migrations — always safe to run
    DefaultCategoryMigration.backfillIsDefaultIfNeeded(modelContext: modelContext)
    DefaultCategoryMigration.backfillSortOrderIfNeeded(modelContext: modelContext)

    let needsAccount = !hasAny(Account.self, in: modelContext)
    let needsCategories = !hasAny(TransactionCategory.self, in: modelContext)

    // Already fully populated — skip the CloudKit wait entirely
    guard needsAccount || needsCategories else { return }

    // Give CloudKit time to import remote data
    await waitForInitialCloudImport()

    if !hasAny(Account.self, in: modelContext) {
        seedDefaultAccount(in: modelContext)   // "Savings", ₹100, primary
    }

    if !hasAny(TransactionCategory.self, in: modelContext) {
        seedDefaultCategories(in: modelContext) // bundled default set
    }
}
```

`waitForInitialCloudImport()` observes CloudKit container events and resumes when an import finishes, or after a 10-second timeout if no import event fires (fresh account, offline, or CloudKit disabled).

### Where it runs: onboarding start, not onboarding *view*

An early design temptation was to attach seeding to `OnboardingCarouselView`’s `.task`. That’s semantically appealing (“seed when onboarding UI appears”) but **fragile**:

- SwiftUI `.task` is tied to view lifetime
- If the user dismisses onboarding quickly, the task can be **cancelled** before the CloudKit wait completes
- You’d be back to partially seeded state

Instead, we trigger from `RootContainerView` when the onboarding **sheet becomes active**:

```swift
.onChange(of: activeSheet) { _, sheet in
    guard case .onboarding = sheet, !didStartSeeding else { return }
    didStartSeeding = true
    Task { await DefaultDataSeeder.seedIfNeeded(modelContext: modelContext) }
}
```

Key details:

- **`Task { }` (unstructured)**, not `.task` — the work survives sheet dismissal
- **`didStartSeeding`** — runs at most once per launch
- **`RootContainerView`** — lives for the entire app session, not just while the carousel is visible

While the user reads welcome copy and swipes through pages, CloudKit import and seeding happen underneath. By **Get Started**, the store is ready.

### What we removed

| Removed | Why |
|---------|-----|
| `DefaultAccountSeeder.swift` | Folded into `DefaultDataSeeder` |
| `ContentView` account `.task` | Wrong trigger; duplicated logic |
| `CategoriesView.onAppear` seeding | Wrong trigger; caused “visit tab to fix data” |
| Scattered production category seed paths | Replaced by unified flow |

We kept a narrow **UI-test-only** category seed in `ContentView` because UI tests launch with `-UITesting`, skip onboarding, and expect categories without accounts — a deliberate test fixture, not production behavior.

---

## Why `@Query` made the fix feel seamless

Once seeding writes into the shared `ModelContext`, SwiftData’s observation layer does the rest.

`TransactionsView`, `UpdateTransactionSheet`, `AccountsView`, and `CategoriesView` all use `@Query`. They don’t need to be open when seeding runs. When rows appear in the store, pickers and lists update **reactively**.

That’s why removing `CategoriesView.onAppear` seeding was safe **only after** seeding moved to an earlier, reliable trigger. The views were never the right place to *decide* to seed; they were just the place where we first *noticed* data was missing.

---

## Before and after

### Before

```
App launch
  └─ ContentView.task → DefaultAccountSeeder (async, CloudKit wait)
User finishes onboarding
  └─ Taps "Add Transaction" → often empty pickers
User opens Categories tab
  └─ CategoriesView.onAppear → DefaultCategorySeeder
  └─ Navigates back → categories now exist
```

### After

```
App launch
  └─ Onboarding sheet appears
       └─ RootContainerView → DefaultDataSeeder (async, CloudKit wait, seed if empty)
User finishes onboarding
  └─ Taps "Add Transaction" → account + categories already in store
```

---

## Lessons learned

### 1. “Seed once” needs a single owner

Two seeders with two triggers will eventually drift. Even if each one is individually reasonable, the **system** becomes unpredictable.

### 2. UI lifecycle is a bad scheduling API

`onAppear` on a secondary tab is not a product event. **Onboarding start** is. Pick triggers that match user intent, not whichever view happened to mount.

### 3. CloudKit changes the meaning of “empty store”

An empty local store on first launch might mean “brand-new user” or “import still in flight.” Always separate:

- **Is the store empty right now?** (fast check)
- **Has CloudKit had a chance to fill it?** (wait, then check again)

### 4. Unstructured `Task` vs view `.task` matters for async setup

If async initialization must outlive a sheet or child view, don’t bind it to that view’s `.task`. Promote it to a longer-lived coordinator.

### 5. Test harnesses need explicit paths

Production onboarding triggers don’t run in UI tests. Keep a deliberate, documented exception (`-UITesting` category seed) rather than accidentally relying on production timing.

---

## Scope note

With this fix, seeding runs when **onboarding starts** — typically first install or when we bump `OnboardingCarouselView.currentVersion` to re-show onboarding after a major update.

Users who already completed onboarding on the current version but somehow have an empty store won’t automatically re-seed. That’s an edge case we accepted in exchange for a clear product rule: *defaults are prepared during onboarding, not on every launch or tab visit.* A future safety net could detect “onboarded but empty” and run the same orchestrator once.

---

## Summary

Spendrift’s first-run experience depends on invisible starter data: a Savings account and a set of categories. We had split that responsibility across multiple files and UI hooks, so users often tapped **Add Transaction** before their data existed — and only discovered accounts or categories after wandering the tab bar.

The fix was not more seeding logic. It was **less**, in the right place:

- One orchestrator (`DefaultDataSeeder`)
- One trigger (onboarding start)
- One CloudKit-aware decision path (wait → check → insert if still empty)
- One shared `ModelContext` so the whole app updates reactively

If you’re building a local-first app with CloudKit and SwiftData, the pattern is worth stealing: **treat default data as infrastructure, not a view concern** — and never make your empty state depend on a tab the user hasn’t opened yet.

---

*Spendrift is developed by Ronak Punase. This article describes a real production fix in the iOS codebase (SwiftUI, SwiftData, CloudKit).*

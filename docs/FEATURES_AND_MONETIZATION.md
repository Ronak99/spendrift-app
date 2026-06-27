# Spendrift — Feature inventory & monetization notes

This document reflects the **current codebase** (not git history): what the app does today, including small caveats and edge cases.

---

## Part 1 — Feature inventory (detailed)

### 1. App shell, navigation, and persistence

1. **Tab bar** — Four tabs: Transactions, Accounts, Categories, Analytics (Statistics).
2. **Shared SwiftData container + CloudKit mirror** — Single `ModelContainer` from `IntentSwiftData` so the main app, App Intents, and widgets read/write the same App Group store, while the app target mirrors accounts/categories/transactions to the user’s private iCloud CloudKit database.
3. **App launch** — `ExpenseAppShortcuts.updateAppShortcutParameters()` runs so Shortcuts see up-to-date intent parameters.
4. **UITest mode** — `-UITesting` forces an in-memory store; onboarding is skipped when testing.
5. **Root sheet priority** — Mandatory App Store update sheet > onboarding > optional update sheet.

### 2. Onboarding

6. **Three-page dark-mode carousel** — Welcome, Siri & Shortcuts, Get Started; pill page indicator; haptic on completion.
7. **Versioned onboarding** — `@AppStorage("spendriftOnboardingVersion")`; bump `OnboardingCarouselView.currentVersion` to show onboarding again after major updates.
8. **Welcome copy** — Highlights multi-account tracking, voice capture, categories, and private storage (local + user iCloud CloudKit). AI calls still send feature-specific data off-device for voice/statement parsing.
9. **Shortcuts page** — Deep links to two iCloud shortcut URLs (`OnboardingShortcutShareLinks`) for “Voice Record Expense” and “Log Expense Amount”; third bullet “Quick Access” has **no URL** (informational only).
10. **Get Started** — Final CTA completes onboarding.

### 3. App updates

11. **iTunes Lookup API** — Compares installed `CFBundleShortVersionString` to App Store version for bundle `com.ronakpunase.Spendrift`.
12. **Semantic versioning rules** — Patch bumps ignored; minor → optional dismissible `AppUpdateSheet`; major → mandatory, non-dismissible sheet.
13. **Store link** — Uses `trackViewUrl` from lookup for “Update” actions.

### 4. Transactions tab

14. **Month-scoped list** — Transactions filtered to selected calendar month (`TransactionViewModel` start/end of month).
15. **Grouped list** — Sections by day, **recent days first**; within a day, transactions sorted by date descending.
16. **Header summary** — Expenses, Income, Savings for the month; color-coded (red/green).
17. **Smart rounding on summary** — If **more than 10** transactions in the month, header uses **whole rupees**; otherwise shows **up to 2 decimal places** (INR).
18. **Capsule month navigator** — Previous/next month; **double-tap** month label → jump to current month; **long-press** month label → “Jump to Month” sheet (year stepper + month grid).
19. **Month picker constraint** — Future months in the grid are **disabled** (cannot navigate past “now”).
20. **First-time gesture hint** — After the user **first leaves the current month** via chevrons, a tooltip explains double-tap and long-press; stored in `AppStorage("hasSeenCapsuleGestureHint")`; auto-dismiss ~5s or tap to dismiss.
21. **Add menu** — “Speak” (voice), “Type” (sheet), “Upload document” (statement import). Voice can be disabled when `voiceInline.blocksNewCapture` is true.
22. **Transaction rows** — Category icon (or generic), category name or “Uncategorized”, account name, amount (INR with decimals per `formatCurrency`), time.
23. **Swipe to delete** — Removes transactions in list.
24. **Tap row** — Opens edit sheet (`UpdateTransactionSheet` with existing transaction).
25. **Empty state** — CTA to add first transaction for that month.
26. **Floating voice bar** — `VoiceInlineRecordingBar` overlays bottom when recording/processing/error; categories passed in **last-used-first** order (see Categories).

### 5. Creating and editing transactions (manual)

27. **Create/edit sheet** — Same `UpdateTransactionSheet`; create vs edit determined by `transaction == nil`.
28. **Fields** — Notes, amount, date, income vs expense, account, category.
29. **Amount entry** — **Whole-number display in text fields** (`wholeAmountDisplayString`); users do not type decimals in the field UI (stored value is still `Double`).
30. **Account picker** — From `@Query` accounts; can create new account from picker flow.
31. **Category picker** — Filtered by transaction type; list order **MRU via `lastUsedAt`**, then never-used alphabetically; search filters by name.
32. **New category** — From picker; new category becomes selection.
33. **Voice draft entry** — Optional `VoiceTransactionDraft` pre-fills fields when voice flow defers to manual entry.
34. **Save** — `selectedCategory?.lastUsedAt = Date()` on save so MRU ordering updates.

### 6. Voice capture (in-app)

35. **Voice policy** — Minimum clip length **2 seconds**; maximum **30 seconds**; auto-submit when max duration reached.
36. **Recording UI** — Cancel, mini waveform, circular progress toward max duration, stop button.
37. **Pipeline** — WAV → optional speech-presence check → **backend AI proxy** (`VoiceTransactionService` → `SpendriftBackendClient`) → JSON payload → `VoiceTransactionCreator` (accounts, categories, SwiftData insert).
38. **Failures** — Too short, no speech, API errors surfaced in UI; Live Activity can show failure/success when ActivityKit is enabled.
39. **Shortcut-imported audio** — Same pipeline after `VoiceShortcutAudioNormalizer` (length/format checks); file copied to caches, then processed.
40. **Live Activities** — `VoiceLiveActivityController` updates state (recording → processing → success/fail); success/failure messages can linger briefly before dismiss (default ~3s).

### 7. Siri Shortcuts & App Intents

41. **Registered shortcuts** — `ExpenseAppShortcuts`: “Log Expense by Speaking” (`VoiceExpenseIntent`), “Log Expense by Typing” (`QuickAmountExpenseIntent`).
42. **`VoiceExpenseIntent`** — `openAppWhenRun: true`. Optional `IntentFile` audio: copies file to app caches, sets `pendingImportPath` in `UserDefaults`; **without** audio, sets `launchTriggerKey` so app opens **compact voice** mode. Posts `voiceExpenseIntentTriggered`.
43. **`QuickAmountExpenseIntent`** — `openAppWhenRun: false`; writes expense **to primary account** via `ShortcutQuickAmountTransaction.create`; optional `ExpenseCategoryEntity` or uncategorized; reloads widgets.
44. **`PromptedQuickExpenseIntent`** — Separate intent for widget “type” flow with required parameters / dialogs.
45. **Category entities for Shortcuts** — `ExpenseCategoryQuery.allEntities()` returns categories **sorted by last usage** (name-sorted fetch + `sortedByLastUsage()`).
46. **Stale category IDs** — Resolve to `nil` so transaction still saves uncategorized.
47. **Intent errors** — Localized: invalid amount, no primary account, unavailable category (where applicable).

### 8. Deep links & home screen

48. **`spendrift://` URLs** — `createTransaction` opens add transaction sheet; `voiceExpense` switches to Transactions tab and triggers compact voice capture.
49. **Home screen quick action** — “Create Transaction” registered in `QuickActionsManager`.
50. **Nitpick** — `AppDelegate` posts `NotificationCenter` **"QuickAction"** with the action type; **no SwiftUI subscriber** was found in `ContentView` for that name—only `onOpenURL` handles `spendrift://`. The **dynamic quick action from the icon** may not open the create sheet unless wired elsewhere.

### 9. Widgets (extension)

51. **Small widget** — Primary account name, balance, monthly expense (rounded INR in widget `formatCurrency`); buttons linking to `spendrift://voiceExpense` and `spendrift://createTransaction`.
52. **Medium “Capture Hub”** — Balance panel + quick-add via `QuickAmountExpenseIntent` with configurable amount/category from widget config.
53. **Large “Recent transactions”** — Month expenses, recent rows, balance; uses `WidgetDataStore` and snapshot models; **widget currency formatting uses 0 decimal places** (separate from main app lists).
54. **Timeline refresh** — ~30 minute refresh policy in providers; intents call `WidgetCenter.shared.reloadAllTimelines()` after quick expense writes.
55. **Voice Live Activity widget** — Extension target includes `VoiceLiveActivityWidget` (lock screen / Dynamic Island integration where enabled).

### 10. Bank statement import (PDF)

56. **Entry** — From Transactions → Add → Upload document → `StatementImportView`.
57. **PDF only** — `UTType.pdf` in file importer; **not** CSV/images.
58. **Size cap** — **20 MB** max; larger files error.
59. **Readable PDF** — Must parse as `PDFDocument`; otherwise unreadable error.
60. **Password-protected PDFs** — `validatePDF` tries `unlock(withPassword: "")`; **encrypted PDFs that do not unlock with empty password** throw `passwordProtected` — **no password entry UI** (user must use an unlocked/exported PDF).
61. **Privacy** — Explicit **privacy notice** and **toggle** “I understand…” required before “Choose PDF” is enabled.
62. **Account binding** — User picks which account receives imported rows (defaults to primary on appear); empty accounts shows guidance to add an account first.
63. **AI parsing** — PDF bytes sent to the **backend AI proxy** (`BankStatementService` → `SpendriftBackendClient`); extracts JSON list of transactions.
64. **Preview** — Editable list of rows; user can **delete rows** before save.
65. **Save behavior** — Inserts `Transaction` per row with **`category: nil`** (imported lines are **not** auto-categorized in the model).
66. **Nitpick** — `TransactionType` comes from parsed JSON; amounts ≤ 0 dropped in mapping.

### 11. Categories

67. **Default seed** — `DefaultCategorySeeder` seeds bundled categories once and stores `hasSeededDefaultCategories` in iCloud KVS to prevent duplicate seeds during CloudKit restore after reinstall.
68. **CRUD** — List, create, edit categories; icons via icon grid picker flow (per existing views).
69. **`lastUsedAt`** — Optional on model; updated on manual save, shortcut expense, and successful voice create.
70. **MRU ordering** — `sortedByLastUsage()` used in transaction sheet, voice bar, and Shortcuts entity query.

### 12. Accounts

71. **Primary account** — `isPrimary` flag; shortcuts and statement import assume a **primary** account for quick paths.
71a. **Default account seed** — `DefaultAccountSeeder` waits for CloudKit's initial import (with a timeout fallback) before seeding a single primary "Savings" account (balance 100) only when no account exists anywhere, so it never collides with synced accounts. Guarded by `hasSeededDefaultAccount` in iCloud KVS.
72. **Balance model** — `currentBalance` derived from opening balance plus income minus expenses on linked transactions.
73. **Per-account transaction screen** — Filtered month view + same patterns as main transactions.

### 13. Analytics (Statistics)

74. **Month selector** — Same `CapsuleDateSelector` behavior as Transactions.
75. **Summary grid** — Spent, Income, Net, Daily average (spend / days in month).
76. **Category donut** — Swift Charts `SectorMark`; legend + row list with share **percentage**; “Uncategorized” bucket when no category.
77. **Daily trend** — Spending by day in month.
78. **Weekday pattern** — Aggregates expenses by weekday.
79. **Empty states** — No transactions for month; or month has data but no expenses (charts gated).
80. **Smart rounding** — Same **>10 transactions** rule for header-style summaries where implemented (Transactions tab); Statistics summary cards use **`formatCurrency`** (decimals up to 2) for the four summary tiles—**inconsistency** with Transactions header if you expect identical rules everywhere.

### 14. Settings & feedback

81. **Theme** — Eight accent colors stored in `@AppStorage("themeColor")`; tab tint and various UI use `Color.themeColors`.
82. **Siri & Shortcuts cards** — Same iCloud shortcut links as onboarding; opens in Safari/Shortcuts.
83. **Feature request** — `FeatureRequestView`: text + optional **photo** attachment; **Mail compose** when available; fallbacks if Mail unavailable.
84. **Share** — `ShareLink` with `AppShareContent` preset text/message.
85. **Profile settings button** — Toolbar entry to open settings from Transactions/Accounts/Categories.

### 15. Misc & developer utilities

86. **Screenshot demo data** — `ScreenshotDemoData.seedIfNeeded` for marketing screenshots.
87. **Debug view** — Simple monospaced scroll (used for debugging).
88. **Currency** — INR `en_IN`; main app lists use up to 2 decimals; widgets use integer rupees in display helpers.
89. **App secrets** — `AppSecrets.backendBaseURL` and `AppSecrets.backendClientToken` for the backend AI proxy (voice + bank statement + receipts).

### 16. Nitpick summary (limits & consistency)

| Area | Detail |
|------|--------|
| Statement import | PDF only; 20 MB; **no password UI**; uncategorized on save; third-party AI. |
| Amount UI | Manual entry shows **integers in text fields**; list display can show paise. |
| Shortcuts | Quick amount = **expense on primary account** only unless user edits shortcut. |
| Widget | **Rounded** currency vs main app decimals. |
| Analytics vs Transactions | Summary rounding rules may **differ** (Transactions uses >10 rule; Statistics cards use standard `formatCurrency`). |
| Home quick action | Notification posted; **no obvious observer** for create-transaction flow. |

---

## Part 2 — Monetization & “Pro” brainstorm (feature-level)

These are **strategies**, not recommendations to implement all at once.

### Tier A — High perceived value, recurring cost

1. **AI voice limits** — Free: N voice parses per month; Pro: higher cap or unlimited (directly ties to backend AI cost).
2. **Statement import** — Free: 1–3 PDFs/month or first N pages; Pro: higher limits or batch (covers API cost + positions as “power user”).
3. **Multi-currency / non-INR** — If added later, Pro-only (or free single currency).

### Tier B — Convenience & power

4. **Widgets** — Free: one small widget; Pro: medium/large, configurable quick amounts, more frequent refresh (if you can justify technically).
5. **Shortcuts “silent”** — Free: `QuickAmountExpenseIntent` with cap; Pro: unlimited or advanced intents (e.g. pick account, not just primary).
6. **Export** — CSV/PDF export of transactions → **classic Pro** feature.
7. **Advanced analytics** — Custom date ranges, yearly view, trends vs budget, category budgets — Pro.

### Tier C — Privacy & trust upsells

8. **On-device only mode** — Marketing: voice/statement require cloud; Pro could still be “cloud” but offer **local-only** tier that disables AI features (inverse paywall: pay for AI, not for privacy).

### Tier D — Growth & retention

9. **Themes** — Free: 2–3 accents; Pro: full palette + app icon.
10. **Family / shared** — If implemented later, this means shared/household collaboration on top of the now-default personal iCloud sync.

### Tier E — Support & goodwill

11. **Feature requests** — Keep free; optionally “Pro priority” badge in feedback email metadata.

### Packaging

- **Single “Spendrift Pro” subscription** — Bundle AI voice + statement import + widgets + export + advanced charts.
- **Consumables** — “AI statement packs” for users who rarely import (one-time purchase).
- **Free trial** — 7 days Pro to habituate voice + import, then gate.

---

## Follow-up

- Consider **aligning rounding rules** between Transactions and Analytics (and documenting widget vs app currency) so monetization copy does not conflict with “precision” messaging.

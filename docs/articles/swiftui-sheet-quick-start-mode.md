# The Sheet That Forgot Its Purpose: Quick Start and SwiftUI Presentation Timing in Spendrift

*Why a first-transaction flow in an expense tracker exposed a subtle SwiftUI bug — and why two `@State` booleans were never enough.*

---

## What is Spendrift?

**Spendrift** is a personal expense tracker for iOS. You log money in and money out, organize it by category, tie it to accounts, and see summaries over time — expenses, income, and savings — for whatever period you are looking at.

Like most finance apps, Spendrift has a cold-start problem. A brand-new user finishes a short onboarding carousel and lands on the **Transactions** tab with no history yet. No rows to scroll. Just an empty screen and a quiet question: *now what?*

That moment matters. If logging your first transaction feels like paperwork, people leave. If it feels like typing a number and tapping Save, they stay.

This article is about one specific moment in that journey: what happens when someone taps **Add Transaction** on that empty screen — and why the code that looked correct opened the wrong kind of sheet anyway.

---

## Act I — The intention

### The empty state

When there are no transactions for the selected month, the Transactions tab shows an **empty state**: a tray icon, a short title (“No Transactions”), copy like “Get started by adding your first transaction for this month,” and a floating **Add Transaction** button.

This is not decoration. It is the first real invitation to do something useful after onboarding.

### What onboarding already prepared

By the time a new user sees that empty state, Spendrift has already done quiet setup work (see [the seeding article](./unified-default-data-seeding.md) for the full story):

- A default **Savings** account
- A curated set of categories, including **Salary** for income and common expense categories like Food

The user should not need to create an account first. They should not need to understand income vs. expense before logging a single rupee.

They should be able to **type an amount and save**.

That product goal has a name inside the codebase: **quick start**.

### What quick start is supposed to do

Quick start is a special mode for opening the “New Transaction” sheet from the empty-state button. When it works, the sheet:

1. Pre-selects **Income** (most people's first meaningful entry is salary or similar)
2. Pre-selects the **Salary** category
3. Pre-selects the first available account (the seeded Savings account)
4. **Auto-focuses the amount field** so the keyboard is already up

The user sees a form that is mostly filled in. They type `50000`, tap Save, and the app comes alive — header totals update, the empty state disappears, momentum begins.

Compare that to the normal manual path: toolbar **+** → **Type** → sheet opens on **Expense** → pick account → pick category → find the amount field → type → save. Fine for day-two usage. Too much for the first thirty seconds in the app.

**Two entry points, two experiences:**

| Entry point | Intended behavior |
|-------------|-------------------|
| Empty state **Add Transaction** | Quick start — Income, Salary, focused amount |
| Toolbar **+ → Type** | Standard — Expense, no auto-focus, user picks everything |

Same sheet component (`UpdateTransactionSheet`). Different initialization. The product intent was clear.

---

## Act II — The implementation

### The sheet: configuration as a `let`

`UpdateTransactionSheet` is a reusable form for creating and editing transactions. For quick start, the parent passes a boolean:

```swift
struct UpdateTransactionSheet: View {
    /// When true (genuine first transaction from the empty-state CTA), the sheet pre-selects the
    /// Salary income category, the first available account, and auto-focuses the amount field.
    let quickStartFirstTransaction: Bool

    @State private var transactionType: TransactionType = .expense
    @State private var selectedCategory: TransactionCategory?
    // ...

    .onAppear {
        if transaction == nil {
            if quickStartFirstTransaction {
                transactionType = .income
                // find Salary, pre-select account, focus amount field
            } else {
                transactionType = .expense
            }
            // ... category selection follows transactionType
        }
    }
}
```

The design is reasonable: the **parent decides which mode**; the **sheet decides what that mode looks like** in `onAppear`.

When `quickStartFirstTransaction` is `true`, the sheet sets `transactionType = .income` and looks up Salary:

```swift
} else if quickStartFirstTransaction {
    transactionType = .income
}

if category == nil, quickStartFirstTransaction {
    category = categoriesSortedByLastUsed.first { $0.type == .income && $0.name == "Salary" }
}
```

When it is `false`, the sheet takes the standard path:

```swift
} else {
    transactionType = .expense
}

if category == nil {
    category = categoriesSortedByLastUsed.first { $0.type == transactionType }
}
```

That fallback is why the bug was so visible: a `false` flag does not mean “blank sheet.” It means **full standard mode** — Expense type, first expense category in the list, no amount focus.

### The parent: two booleans

`TransactionsView` owned presentation. Before the fix (commit `631ab0f`), it used **two separate pieces of state**:

```swift
@State private var showCreateSheet = false
@State private var createSheetQuickStart = false
```

Empty-state button:

```swift
action: {
    createSheetQuickStart = true
    showCreateSheet = true
}
```

Toolbar “Type” button:

```swift
Button {
    createSheetQuickStart = false
    showCreateSheet = true
}
```

Sheet presentation:

```swift
.sheet(isPresented: $showCreateSheet) {
    UpdateTransactionSheet(
        transaction: nil,
        quickStartFirstTransaction: createSheetQuickStart
    )
}
```

On paper, this reads well. One boolean opens the sheet. The other configures it. The argument `createSheetQuickStart` is passed straight into `UpdateTransactionSheet`. What could go wrong?

Quite a lot, as it turns out — and none of it was visible in the parent's button handler.

---

## Act III — The problem

### What users saw

Tap **Add Transaction** on the empty state. The sheet opens. But it behaves like the toolbar path:

- Type is **Expense**, not Income
- Category is the first **expense** category (e.g. Food), not Salary
- The amount field is **not** focused

Quick start never happened. The empty-state CTA and the toolbar **Type** button produced the same experience.

### The debugging trap

This is where the bug earns its article.

Breakpoint inside `UpdateTransactionSheet.onAppear`:

```swift
quickStartFirstTransaction == false   // always, from empty-state CTA
```

Inspect the parent right after the button fires:

```swift
createSheetQuickStart == true   // parent thinks it did the right thing
showCreateSheet == true
```

The parent set the flag. The sheet received `false`. Same button tap. Two truths.

Reasonable suspects that turn out to be red herrings:

- Categories not loaded yet? Unlikely — Salary is seeded during onboarding.
- `EmptyStateView` not calling the action? It was.
- Logic inside the `if quickStartFirstTransaction` branch? It never ran because the value was already wrong at initialization.

The bug was not in the quick-start **logic**. It was in the quick-start **delivery**.

### Why passing `createSheetQuickStart` as an argument did not work

This is the heart of the issue.

The argument **was wired correctly** in source code:

```swift
quickStartFirstTransaction: createSheetQuickStart
```

There was no typo. No wrong parameter label. No missing binding. And yet `UpdateTransactionSheet` was still constructed with `false`.

The reason is **when** SwiftUI evaluates that expression.

`.sheet(isPresented:)` watches one thing: `showCreateSheet` flipping from `false` to `true`. That flip is what triggers presentation.

The **mode** lives in a **different** `@State` property: `createSheetQuickStart`. SwiftUI does not treat them as one unit. Presentation is driven by binding A; the content closure reads binding B.

When the empty-state button runs:

```swift
createSheetQuickStart = true    // state A — intent
showCreateSheet = true          // state B — trigger
```

Both assignments happen in the same action, but SwiftUI's update pipeline does not guarantee they are visible together at the instant the sheet content closure runs. Presentation can begin in response to `showCreateSheet`, SwiftUI invokes the content closure to build `UpdateTransactionSheet`, and that closure reads `createSheetQuickStart` while it is **still `false`** from the previous render.

Visually:

```
Before tap
├── showCreateSheet        = false
├── createSheetQuickStart  = false
└── sheet not presented

User taps "Add Transaction"
├── createSheetQuickStart = true    ← your intent
├── showCreateSheet = true          ← presentation trigger

SwiftUI presents sheet
├── .sheet(isPresented:) reacts to showCreateSheet
├── content closure runs
├── reads createSheetQuickStart → false   ← stale sibling state
└── UpdateTransactionSheet(init: quickStartFirstTransaction: false)

Next render
└── createSheetQuickStart = true    ← too late; child already initialized
```

The sheet opened. The configuration did not make the trip.

This is a **sibling-state staleness** bug: two `@State` properties updated together are not guaranteed to be read together when the sheet content builder runs.

### Why the sheet still selected an expense category

Because `quickStartFirstTransaction` is a **`let`**, not `@State` or a `@Binding`. It is fixed at initialization.

When the sheet is born with `false`:

1. `onAppear` runs the `else` branch → `transactionType = .expense`
2. Salary lookup is skipped (`if category == nil, quickStartFirstTransaction` is never true)
3. The generic fallback runs → first category matching `.expense`
4. `focusAmountFieldSoon()` is never called

The parent may show `createSheetQuickStart == true` on the very next frame. The child does not care. It already committed to standard mode for this entire presentation.

That is why the bug felt haunted: **the code you wrote was correct, the state you set was correct, and the user experience was wrong anyway.**

### Why `showCreateSheet` alone was not enough

`showCreateSheet` answers only one question: **should the sheet be visible?**

It carries no information about **how** the sheet should open. Quick start vs. standard mode lived entirely in a second variable.

That split created three problems:

1. **No atomicity** — “open” and “open in mode X” were two writes, racing against presentation timing.
2. **No identity** — `.sheet(isPresented:)` presents the same sheet slot whether you meant quick start or standard; only a sibling bool differed.
3. **No reliable payload** — the content closure captured `createSheetQuickStart` from the parent's render context, not from the user's intent as a single value.

`showCreateSheet = true` was necessary but not sufficient. You also needed the mode to arrive at the sheet **at the exact moment of presentation**. A separate bool could not guarantee that.

### Why assignment order did not save us

```swift
createSheetQuickStart = true
showCreateSheet = true
```

vs.

```swift
showCreateSheet = true
createSheetQuickStart = true
```

Neither order is a reliable contract. You are coordinating two independent state variables against framework timing. Sometimes one order appears to work on one iOS version. That is luck, not design.

---

## Act IV — The resolution

### The principle

If a sheet needs configuration to build itself, **the thing that triggers presentation should be the same thing that carries the configuration.**

Do not split “should show” and “what to show” across two `@State` siblings when the second one affects sheet content.

### Why `CreateTransactionSheetMode` mattered

The fix (commit `631ab0f`) replaced two booleans with one optional enum:

```swift
/// Drives the manual create-transaction sheet so quick-start mode is chosen atomically with presentation.
private enum CreateTransactionSheetMode: Identifiable {
    case standard
    case quickStartFirst

    var id: Self { self }

    var quickStartFirstTransaction: Bool {
        self == .quickStartFirst
    }
}

@State private var createTransactionSheet: CreateTransactionSheetMode?
```

The enum matters for three reasons:

**1. Presentation and mode are one assignment**

```swift
// Empty state
createTransactionSheet = .quickStartFirst

// Toolbar "Type"
createTransactionSheet = .standard
```

There is no second write. No sibling to go stale. The value that makes the optional non-nil **is** the mode.

**2. `.sheet(item:)` passes that value into the content closure**

```swift
.sheet(item: $createTransactionSheet) { mode in
    UpdateTransactionSheet(
        transaction: nil,
        quickStartFirstTransaction: mode.quickStartFirstTransaction
    )
}
```

When the sheet is created, `mode` comes directly from the item that triggered presentation — not from a separate `@State` property that might still reflect the previous render.

```
createTransactionSheet = .quickStartFirst
         │
         ├── non-nil → sheet presents
         └── .quickStartFirst → passed to content closure as `mode`
```

**3. Named cases scale better than a raw bool**

`standard` vs. `quickStartFirst` documents intent at the call site. A future third mode (e.g. prefilled from a receipt import) becomes another enum case instead of another loosely related `@State` flag.

`Identifiable` is required for `.sheet(item:)`. Using `var id: Self { self }` on a small finite enum is idiomatic when each case is already unique.

### What we removed

| Before | After |
|--------|-------|
| `showCreateSheet: Bool` | Removed — presentation is `createTransactionSheet != nil` |
| `createSheetQuickStart: Bool` | Removed — mode is the enum case |
| `.sheet(isPresented:)` | `.sheet(item:)` |
| Two assignments per button tap | One assignment per button tap |
| Dismiss via `showCreateSheet = false` | Dismiss via `createTransactionSheet = nil` |

Voice capture, receipt import, and shortcut flows that previously dismissed the create sheet now set `createTransactionSheet = nil` — same semantics, cleaner model.

### Expected behavior after the fix

From the empty state:

1. Type defaults to **Income**
2. Category defaults to **Salary**
3. First account is pre-selected
4. Amount field auto-focuses after a short delay (~0.5s for the presentation animation to settle)

From the toolbar **Type** menu:

1. Type defaults to **Expense**
2. Category defaults to the first expense category
3. No auto-focus

Same sheet. Different mode. Finally delivered correctly.

---

## Before and after

### Before (broken)

```
Empty-state tap
  └─ createSheetQuickStart = true
  └─ showCreateSheet = true
       └─ .sheet(isPresented:) fires
            └─ closure reads createSheetQuickStart → false (stale)
                 └─ UpdateTransactionSheet(quickStartFirstTransaction: false)
                      └─ onAppear: Expense + first expense category
```

### After (fixed)

```
Empty-state tap
  └─ createTransactionSheet = .quickStartFirst
       └─ .sheet(item:) fires with mode == .quickStartFirst
            └─ UpdateTransactionSheet(quickStartFirstTransaction: true)
                 └─ onAppear: Income + Salary + focus amount
```

---

## The journey, summarized

| Stage | What happened |
|-------|---------------|
| **Product** | New users need a frictionless first transaction after onboarding |
| **Design** | Empty-state CTA gets quick start; toolbar keeps the full manual path |
| **Implementation** | Two `@State` booleans — one to show, one to configure |
| **Bug** | Sheet presented with stale config; quick start silently became standard Expense mode |
| **Fix** | `CreateTransactionSheetMode` enum + `.sheet(item:)` — trigger and payload unified |

---

## Lessons learned

### 1. `isPresented` + sibling `@State` is a code smell

When sibling state affects sheet content, treat this pattern as risky:

```swift
// Risky
.sheet(isPresented: $isShowing) {
    Editor(mode: currentMode)
}
```

Prefer:

```swift
// Safer
.sheet(item: $editorContext) { ctx in
    Editor(mode: ctx.mode)
}
```

### 2. Immutable `let` config amplifies the bug

Wrong init means wrong behavior for the **entire** presentation. There is no self-correction on the next parent render.

### 3. A false bool is not a neutral default

In `UpdateTransactionSheet`, `quickStartFirstTransaction: false` actively selects Expense and the first expense category. Passing the wrong value is not “missing quick start” — it is **choosing the other product path**.

### 4. The same bug class appears elsewhere

`.fullScreenCover(isPresented:)`, `.popover(isPresented:)`, and some `navigationDestination` patterns have the same sibling-state staleness risk whenever configuration lives outside the presentation trigger.

### 5. Product and framework have to agree

Quick start is a product decision: the empty state is not saying “here is a form.” It is saying “log your salary — we will handle the rest.” That only works if the sheet receives the right mode at birth.

---

## Try it yourself

Minimal reproduction, no expense tracker required:

```swift
struct StaleSheetDemo: View {
    @State private var showSheet = false
    @State private var useSpecialMode = false

    var body: some View {
        Button("Open (quick start)") {
            useSpecialMode = true
            showSheet = true
        }
        .sheet(isPresented: $showSheet) {
            Text(useSpecialMode ? "QUICK START" : "STANDARD")
                .font(.largeTitle)
                .onAppear { print("mode =", useSpecialMode) }
        }
    }
}
```

Tap the button a few times. On many OS versions you will see STANDARD and `mode = false` in the console even though you set `useSpecialMode = true` in the same action.

Fixed version:

```swift
enum SheetMode: Identifiable {
    case standard, quickStart
    var id: Self { self }
}

@State private var mode: SheetMode?

Button("Open (quick start)") { mode = .quickStart }

.sheet(item: $mode) { m in
    Text(m == .quickStart ? "QUICK START" : "STANDARD")
}
```

Same framework. Same button. One value instead of two. The sheet finally remembers what it was opened for.

---

## Suggested Medium title

**The Sheet That Forgot Its Purpose: A SwiftUI Timing Bug in a First-Transaction Flow**

Subtitle: *Why two `@State` booleans made an expense tracker’s “quick start” silently open as a standard expense form — and how one enum fixed it.*

---

*Spendrift is a personal expense tracker for iOS, built with SwiftUI and SwiftData. This article describes a real production fix (commit `631ab0f`): unifying transaction sheet presentation so quick-start mode from the empty state is chosen atomically with presentation, not via a stale sibling boolean.*

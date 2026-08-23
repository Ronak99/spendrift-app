# How Senior iOS Developers deal with SwiftUI sheet timing bugs.

*A real SwiftUI bug where the right button was tapped, the right state was set, and the sheet still opened in the wrong mode.*

SwiftUI sheet bugs rarely announce themselves as framework timing bugs.

They usually look smaller than that.

A button opens the wrong form.
A default selection is missing.
The keyboard does not focus.
A breakpoint says the parent state is correct, while the child view insists it received something else.

That is the kind of bug senior iOS developers learn to slow down for.
Not because the code is complex, but because the timing is.

This article uses a real first-transaction flow from Spendrift, a SwiftUI expense tracker, to look at one of those bugs.
The product detail is simple: a new user lands on an empty Transactions screen and taps **Add Transaction**.
That sheet should open in quick-start mode, ready for the user to type an amount and save.

Instead, it opened like the normal toolbar sheet.
Expense selected.
First expense category selected.
No focused amount field.

The user tapped the right button.
The app did the wrong thing.

## The UX That Was Supposed To Happen

The first transaction matters more than it looks.

When someone opens a finance app for the first time, they do not want to configure accounts, categories, and transaction types before the product proves it is useful.
They want to enter a number and feel the app come alive.

In this flow, onboarding had already created a default account and a few starter categories.
So the empty-state **Add Transaction** button had one job: open the sheet in quick-start mode.

Quick start meant:

- Select **Income**.
- Select **Salary**.
- Pick the first available account.
- Focus the amount field after the sheet settles.

The toolbar button still opened the same `UpdateTransactionSheet`, but in the standard mode.
That path started as **Expense**, selected the first expense category, and left the form for the user to complete manually.

Same sheet.
Different intent.

That distinction is exactly where the bug lived.

## The Code Looked Reasonable

The parent view used two pieces of state.
One decided whether the sheet was visible.
The other decided whether the sheet should use quick-start behavior.

```swift
@State private var showCreateSheet = false
@State private var createSheetQuickStart = false
```

The empty-state button set quick start first, then opened the sheet.

```swift
createSheetQuickStart = true
showCreateSheet = true
```

The toolbar path did the opposite mode.

```swift
createSheetQuickStart = false
showCreateSheet = true
```

The sheet read the value from the parent.

```swift
.sheet(isPresented: $showCreateSheet) {
    UpdateTransactionSheet(
        transaction: nil,
        quickStartFirstTransaction: createSheetQuickStart
    )
}
```

Inside the sheet, the configuration was a plain immutable value.

```swift
struct UpdateTransactionSheet: View {
    let quickStartFirstTransaction: Bool

    @State private var transactionType: TransactionType = .expense
    @State private var selectedCategory: TransactionCategory?

    var body: some View {
        // ...
    }
}
```

On appear, the sheet used that value to decide its initial state.

```swift
if quickStartFirstTransaction {
    transactionType = .income
    selectedCategory = salaryCategory
    focusAmountFieldSoon()
} else {
    transactionType = .expense
    selectedCategory = firstExpenseCategory
}
```

There is nothing obviously careless here.
That is what makes this bug useful.

The parent had a flag.
The button set the flag.
The sheet received the flag.
The sheet had a branch for the flag.

And yet the branch never ran.

## The Moment That Gives The Bug Away

The first instinct is to inspect the business logic.

Maybe the Salary category was not seeded.
Maybe the empty-state button was not firing.
Maybe the sheet was overriding the type later.
Maybe the focus delay was too short.

All reasonable guesses.
All wrong.

The important breakpoint was not deep in category selection.
It was at the start of the sheet.

```swift
quickStartFirstTransaction == false
```

That was the value inside `UpdateTransactionSheet` when opened from the empty-state CTA.

Then the parent was inspected right after the button action.

```swift
createSheetQuickStart == true
showCreateSheet == true
```

Both statements were true.
The parent believed quick start was enabled.
The sheet was initialized with quick start disabled.

Senior iOS developers pay attention to that contradiction.
When parent state and presented content disagree, the bug may not be the value.
It may be the moment SwiftUI read the value.

## The Real Problem: Two States For One Presentation

`.sheet(isPresented:)` is driven by one binding.
In this case, that binding was `showCreateSheet`.

The mode lived somewhere else.
It was a sibling `@State` value named `createSheetQuickStart`.

Those two values looked connected because the button action updated them together.
SwiftUI did not treat them as one atomic presentation request.

This was the shape of the bug:

```swift
createSheetQuickStart = true
showCreateSheet = true
```

The first line expressed intent.
The second line triggered presentation.

But the sheet content closure belonged to the presentation trigger.
SwiftUI could begin building the sheet because `showCreateSheet` changed, while the closure still observed the previous rendered value of `createSheetQuickStart`.

So the child was born with this:

```swift
UpdateTransactionSheet(
    transaction: nil,
    quickStartFirstTransaction: false
)
```

By the time the parent reflected `createSheetQuickStart == true`, the sheet had already made its first decision.

That matters because `quickStartFirstTransaction` was a `let`.
The sheet did not receive a binding that could correct itself on the next render.
It received an initialization value.

Wrong at birth meant wrong for the whole presentation.

This is the bug class: sibling-state staleness during presentation.
It happens when one state variable opens a sheet and another state variable configures the sheet.

The code reads like a single action.
The framework sees separate state changes.

## Why Assignment Order Is Not A Fix

It is tempting to treat this as an ordering problem.

Maybe this works:

```swift
createSheetQuickStart = true
showCreateSheet = true
```

Maybe this works better:

```swift
showCreateSheet = true
createSheetQuickStart = true
```

That line of thinking is the trap.

Changing the order may appear to fix the bug on one device, one OS version, or one local build.
It does not give the sheet a reliable payload.
It still leaves presentation in one state value and configuration in another.

A senior fix does not try to win the race.
It removes the race.

## The Fix: Make The Sheet Item Carry The Mode

The fix was to replace the two booleans with one optional enum.

```swift
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

Now the empty-state button performs one assignment.

```swift
createTransactionSheet = .quickStartFirst
```

The toolbar performs one assignment too.

```swift
createTransactionSheet = .standard
```

Presentation moves from `.sheet(isPresented:)` to `.sheet(item:)`.

```swift
.sheet(item: $createTransactionSheet) { mode in
    UpdateTransactionSheet(
        transaction: nil,
        quickStartFirstTransaction: mode.quickStartFirstTransaction
    )
}
```

That is the whole design change.

The thing that opens the sheet now carries the information required to build the sheet.
There is no second sibling value to be read at the wrong time.
The item is both the trigger and the payload.

When `createTransactionSheet` becomes `.quickStartFirst`, SwiftUI presents a sheet for that item and passes that exact mode into the content closure.
The sheet no longer asks a separate state variable what kind of sheet it should be.

## What Changed For The User

From the user's point of view, the fix is boring in the best way.

They tap **Add Transaction** on the empty state.
The sheet opens with **Income** selected.
**Salary** is already selected.
The first account is already selected.
The amount field focuses after the presentation animation.

They type `50000`, tap Save, and the empty state disappears.

No one sees the enum.
No one knows `.sheet(item:)` was involved.
The product simply keeps its promise.

That is often what good SwiftUI architecture feels like from the outside: nothing surprising happens.

## The Pattern To Remember

If the sheet's content depends on context, avoid this shape:

```swift
@State private var isShowingEditor = false
@State private var editorMode: EditorMode = .standard

.sheet(isPresented: $isShowingEditor) {
    Editor(mode: editorMode)
}
```

Prefer this shape:

```swift
@State private var editorPresentation: EditorPresentation?

.sheet(item: $editorPresentation) { presentation in
    Editor(mode: presentation.mode)
}
```

Use `.sheet(isPresented:)` when visibility is the only state that matters.
Use `.sheet(item:)` when the sheet needs identity, mode, selected model, source action, or any other context at creation time.

The same principle applies to popovers, full-screen covers, and navigation destinations.
If presentation and payload are split, ask whether SwiftUI can ever observe them out of sync.

## The Senior Debugging Habit

The lesson is not simply "use `.sheet(item:)`."

The deeper lesson is to model presentation as data.

When a sheet opens, it is usually not just "showing."
It is showing for a reason.
It may be editing a transaction, creating from a template, importing from a receipt, or helping a first-time user get through the empty state.

That reason should not be scattered across sibling booleans.
It should be a value the UI can hand to SwiftUI at the moment of presentation.

That is how you avoid timing bugs that only appear between a button tap and the next render.
That is also how you make the code read like the product decision it represents.

The bug in Spendrift was small enough to hide inside two lines of state assignment.
The fix was small too.
But the principle is bigger: when SwiftUI asks what to present, answer with one complete value.

Not a trigger here and a mode over there.
One value.
One presentation.
One source of truth.

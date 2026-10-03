# The Mysterious +/- Button on Your App Intent Amount Prompt, and How to Remove It

*A small iOS widget bug where the system asked for an expense amount and offered a way to make it negative.*

Some bugs live in your code.
This one lived in a screen we never wrote.

Spendrift is a SwiftUI expense tracker for iOS.
Its small home screen widget has a **Type** button.
Tap it, and iOS asks for an amount, a category, and a note, then logs the expense without opening the app.

The amount prompt looked fine at first glance.
A big **Amount** field.
A number pad.
**Cancel** and **Done** buttons.

Then you notice the floating pill above the keyboard.

It says **+/-**.

Tapping it flips the sign of whatever you typed.
So a user can enter an expense of minus forty rupees, tap **Done**, and be told "Enter an amount greater than zero."

Nobody wants a negative expense.
The button should not exist on this screen.
This article is about why it does, and the two lines that make it go away.

---

## Where the screen comes from

If you build an App Intent with a required parameter and the intent runs without a value for it, iOS asks the user.
You do not write that dialog.
The system renders it from the parameter's declared type.

Here is the intent behind Spendrift's **Type** button, trimmed down:

```swift
struct PromptedQuickExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Expense by Typing"
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Amount",
        description: "Expense amount (greater than zero).",
        requestValueDialog: "Amount"
    )
    var amount: Double

    @Parameter(title: "Category", requestValueDialog: "Category")
    var category: ExpenseCategoryEntity

    @Parameter(title: "Notes", requestValueDialog: "Notes")
    var notes: String

    func perform() async throws -> some IntentResult {
        // Validates amount > 0, then saves the expense.
    }
}
```

The `amount` parameter is a plain `Double`.
That single fact is the whole bug.

---

## Why iOS adds the sign toggle

A `Double` can be negative.
Nothing in the declaration above tells the system otherwise.

So when iOS builds a prompt for that parameter, it does the safe thing.
It shows a decimal keypad, and it adds a way to enter a negative number.
On iOS 26 that is the floating **+/-** pill you see above the keyboard.

From the framework's point of view this is correct.
It has no idea the number is money.
It only knows the type is signed.

The same applies to `Int` parameters.
Declare `var count: Int` and the prompt will happily let the user type a negative count.

The description string, "Expense amount (greater than zero)", does not help.
It is documentation for people, not a constraint the system can act on.

---

## The fix: tell the system the real range

The `@Parameter` initializer for numeric types accepts two arguments most people skip.

`inclusiveRange` declares the lowest and highest value the parameter accepts.
`controlStyle` picks how the parameter is edited inside the Shortcuts app.

Here is the same parameter after the fix:

```swift
@Parameter(
    title: "Amount",
    description: "Expense amount (greater than zero).",
    controlStyle: .field,
    inclusiveRange: (0, 1_000_000_000),
    requestValueDialog: "Amount"
)
var amount: Double
```

Two things changed.

**The range starts at zero.**
Now the system knows a negative value is invalid.
It has no reason to offer a sign toggle, so the prompt is just a number pad.

**The control style is a field.**
The default for `Double` is `.stepper`.
A stepper makes sense for "number of retries".
It makes no sense for an expense amount, where users type the number directly.

The upper bound is a large round number.
`inclusiveRange` is a tuple, so you must give both ends.
Pick something no real expense will reach.

---

## What the range does and does not do

The range is validated before your `perform()` runs.
If a value falls outside it, iOS shows its own error and re-prompts.

That is nice, but do not throw away your own validation.

The range starts at zero, and zero is within it.
Spendrift still rejects a zero amount at save time:

```swift
guard amount > 0 else { throw Failure.invalidAmount }
```

You could set the lower bound to `0.01` instead.
We chose not to.
A system error that says "the value must be at least 0.01" reads worse than "Enter an amount greater than zero".
The range handles the sign.
Your code handles the meaning.

---

## Apply it everywhere the parameter appears

An amount parameter rarely lives in one place.

In Spendrift it appears three times:

1. The prompted intent behind the widget's **Type** button.
2. The shortcut intent that Siri and the Shortcuts app expose.
3. The widget configuration intent, where the user sets a default tap amount.

All three take a `Double` amount.
All three got the same range and control style.

If you keep a copy of your intent files in a widget extension target, remember to update that copy too.
It is easy to fix the app target and ship a widget that still shows the old prompt.

---

## A note on IntentCurrencyAmount

App Intents also has a dedicated money type, `IntentCurrencyAmount`.

It pairs a decimal value with a currency code, and its `@Parameter` initializer has `inclusiveRange` and `currencyCodes` arguments.
For a brand new intent it is worth a look.

We did not switch to it here.
Changing a parameter's type changes the intent's shape.
Every shortcut a user has already built on top of the old `Double` would need to be rebuilt.
For a bug this small, breaking existing shortcuts was the wrong trade.

If you are starting fresh, weigh it.
If you are fixing a shipped intent, add the range and move on.

---

## How to check it yourself

There is no unit test for a system prompt.

The check is manual:

1. Add the widget to your home screen.
2. Tap the button that triggers the prompted intent.
3. Look above the keyboard.

Before the fix, the **+/-** pill floats there.
After the fix, it is gone and only the number pad remains.

Also open the Shortcuts app and add your intent as an action.
The amount parameter should show a text field, not a stepper.

---

## Takeaways

**The system builds prompts from types, not from descriptions.**
If a `Double` can be negative, the prompt will let it be negative.

**Declare the real range.**
`inclusiveRange` is the only way to tell iOS that a number has a floor or a ceiling.

**Pick a sensible control style.**
`.field` for values people type, `.stepper` for small counts, `.slider` for percentages.

**Keep your own validation.**
The range filters the obviously wrong.
Your `perform()` still owns the rules that matter.

**Fix every copy.**
Intents shared between an app and a widget extension are easy to update in one place and forget in the other.

It took one screenshot to spot this bug.
It took two arguments to fix it.
The hard part was knowing the arguments exist.

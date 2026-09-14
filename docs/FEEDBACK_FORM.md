# Feedback page - multi-step form

Proposal only.
No implementation in this document.

Feedback becomes its own page in the app, not a mail sheet bolted onto Settings.
The existing `FeatureRequestView` (free-text idea plus optional screenshot, sent by Mail) stays as the skip destination, not as the default path.

---

## Page chrome

Every step of the form uses the same navigation bar:

- **Back** on the top left. Goes to the previous step. On the first step it dismisses the page.
- **"Feedback"** as the centered title on every step, including the skip destination.
- **Next** on the top right. Advances when the current step has an answer. Disabled until something is selected.

A persistent **Skip to notes** control lives outside the step itself.
Place it as a text button under the question, or as a tertiary action at the bottom of the page.
It jumps the user out of the structured form and onto a notes page where they can write freely, request a feature, or dump whatever they actually came to say.

The notes page is the current feature-request surface: a text field, optional screenshot, send.
Do not force people who already know what they want to say through ten rating screens.

Next on the last structured step submits the form (and can still offer an optional notes coda).
Back from notes returns to the step they skipped from, unless they already sent.

---

## Input rules

Only two input types on structured steps:

1. **0 to 5 stars.** Use for quality, accuracy, delight, and "how much do you want this."
   0 is a valid answer ("I have not used this" or "this does not work for me"), not a missing answer.
2. **Multi-choice.** Single-select unless the question is explicitly marked multi-select.
   Keep option lists short (4 to 6). Always include an honest out: **Not sure**, **Haven't used it**, or **Other**.

No sliders, no free text, no numeric keyboards on the structured path.
Free text belongs only on the skip / notes page.

Prefer one question per step.
A screen that asks two things at once will be skipped or answered carelessly.

---

## Locked-in steps

These two are already decided.
They should stay first.

### 1. UI approval

**Question:** How does the app look and feel?
**Input:** 0 to 5 stars.

This is the first impression score for chrome, type, colour wash, lists, and sheets.
It is not "do you like Spendrift."
It is specifically visual and interaction quality.

0 can mean "I have not formed an opinion yet."
Treat 1 to 2 as a design problem, 4 to 5 as "do not restyle this."

### 2. Found where

**Question:** Where did you find Spendrift?
**Input:** Single-select.

- Facebook
- Reddit
- Instagram
- Other

**Suggested extra options** (keep the four above if you want the list tiny, otherwise add these because they match how the app actually grew):

- YouTube
- App Store search
- A friend
- Shortcuts / Apple community

YouTube is the only proven acquisition channel in `BUSINESS_GROWTH_STRATEGY.md`.
Reddit is already a planned secondary layer.
Facebook and Instagram are the paid/social surfaces you named.
Without YouTube and App Store on this list, a large share of real installs will collapse into Other, which is almost useless.

If the list stays at four, that is fine.
Just know Other will be noisy.

---

## What the rest of the form is for

Spendrift is a privacy-first, on-device ledger with four capture styles (type, voice, receipt, statement PDF) plus Shortcuts, widgets, SMS automations, and a Pro gate on the AI calls.

PostHog can tell you *what people did*.
This form is for *why*, *what they wanted instead*, and *what they will not do*.

The steps below are ordered so early answers are useful even if someone bails, and later answers get more specific.

A practical cap is **10 to 12 structured steps** plus the optional notes page.
Everything in the "full catalog" section can be swapped in, branched, or dropped.
The **recommended set** is the one to ship first.

---

## Recommended set (ship these)

Steps 1 and 2 are the locked-in ones above.
Then:

### 3. Why they opened it

**Question:** What are you mainly using Spendrift for?
**Input:** Single-select.

- Just log spending, as little effort as possible
- See where money went this month
- Import a bank statement and be done
- Track more than one account
- Replace another expense app

**Why:** The product is built as a lazy capture ledger, not a budget OS.
This answer tells you whether the current promise matches the user, or whether they arrived expecting YNAB / Wallet / a net-worth dashboard.

### 4. How they want to capture

**Question:** How do you prefer to add a transaction?
**Input:** Single-select. (Multi-select if you want "I use more than one.")

- Type it in the app
- Speak it
- Scan a receipt
- Upload a bank statement
- Bank SMS, automatically
- Widget or Shortcut, without opening the app
- Haven't added one yet

**Why:** Capture is the whole product.
Voice, receipt, PDF, and SMS are the four Pro-gated AI features.
Widget / Shortcut is the free power-user path (Explore, onboarding, Action Button).
If most people pick "type it," Pro is a tax on a minority.
If they pick "haven't added one yet," the form is catching pre-activation users and later feature questions should be skipped.

### 5. Capture quality

**Question:** When you add something, how often does Spendrift get it right?
**Input:** 0 to 5 stars.

Show this only if step 4 was not "Haven't added one yet."
Optional follow-up (same step or the next one) if they pick speak / receipt / statement / SMS:

**Question:** Which capture feels least reliable?
**Input:** Single-select.

- Voice
- Receipt scan
- Statement PDF
- Bank SMS
- Manual typing
- Not sure

**Why:** AI accuracy is the actual cost center and the actual magic.
A star on "the app" will not tell you if voice miscategorises Food as Shopping, or if PDF import dumping everything as Uncategorized is the thing people bounce on.

### 6. Privacy bargain

**Question:** How do you feel about sending a voice clip, receipt photo, or statement to be read?
**Input:** Single-select.

- Fine, as long as the ledger stays on my phone
- I only want on-device, even if capture is dumber
- I don't think about it
- I won't use those features

**Why:** The brand is on-device SwiftData with no iCloud and no user accounts.
Voice, receipts, and PDFs still leave the device through the backend AI proxy.
This is the one preference that decides whether "privacy-first" is a selling point or a contradiction, and whether an on-device-only mode is worth building.

### 7. Habit and reminders

**Question:** How often do you want to log?
**Input:** Single-select.

- In the moment, every spend
- Once a day
- Once a week
- Once a month, from a statement
- Only when I remember

Then, only if they did not pick "Once a month":

**Question:** Daily reminder?
**Input:** Single-select.

- Yes, I want the nudge
- No, reminders would annoy me
- I already turned it off
- Haven't noticed it

**Why:** Preferences currently *is* the reminder toggle.
Default is on.
The first-transaction prompt is easy to miss.
This tells you whether the nudge is a retention tool or a uninstall reason, and whether statement-once-a-month users should even see a daily bell.

### 8. Home screen and Shortcuts

**Question:** Have you set Spendrift up outside the app?
**Input:** Multi-select.

- Home screen widget
- Siri or Shortcuts
- Action Button / Back Tap
- Bank SMS automation
- None of these

**Why:** Onboarding and Explore exist almost entirely to push Shortcuts.
SMS setup is a six-step Shortcuts automation.
Widgets are free and unused by anyone who never adds one.
This is the "did the power-user surface land" question.
If the answer is mostly None, the onboarding Shortcuts page is failing, not the capture engine.

### 9. Analytics usefulness

**Question:** Does the Analytics tab help you?
**Input:** 0 to 5 stars.

Then:

**Question:** What would you want to see more of?
**Input:** Single-select.

- Category breakdown is enough
- Budgets / limits per category
- Longer than one month (year, custom range)
- Recurring bills
- Nothing, I barely open it
- Haven't opened it

**Why:** Statistics today is month-scoped: spent, income, net, daily average, donut, daily trend, weekday pattern.
No budgets, no year view, no export.
This is the cleanest signal for whether "advanced analytics" from the old monetization brainstorm is real demand or a competitor checkbox.

### 10. Missing piece

**Question:** If we built one thing next, what should it be?
**Input:** Single-select.

- Budgets
- Export (CSV / PDF)
- Recurring transactions
- iCloud / device sync
- Split / shared expenses
- Better categories
- Something else (send them to notes)

**Why:** These are the gaps that actually exist in the current app:

- No budgets.
- No export.
- No recurring.
- Local-only store, no iCloud, no account.
- No household / split.
- Categories are a small seeded set (Salary, Food, Groceries, Transport, Bills, Rent, Shopping, Health, Miscellaneous) plus whatever the user adds.
- Currency follows the device locale, with an INR-leaning history and no in-app picker.

This is the roadmap vote.
"Something else" should deep-link to the notes page with the prompt pre-focused.

### 11. Pro value

**Question:** Are the AI features worth paying for?
**Input:** 0 to 5 stars.

Then:

**Question:** What is closest to how you see Pro?
**Input:** Single-select.

- I would pay for voice / SMS / receipts / statements
- Free limits are enough
- I would pay if it included budgets / export / sync
- I don't want a subscription
- I already subscribe
- I haven't hit the paywall

**Why:** Pro today gates only the four AI calls.
Widgets, analytics, themes, and Shortcuts stay free.
Free monthly allowances are 10 voice, 30 SMS, 5 receipts, 1 statement.
If people rate Pro 1 star because they wanted sync and export, the packaging is wrong, not the price.
If they say "free limits are enough," the trial-after-first-success placement is working as designed.

### 12. Would you recommend it

**Question:** Would you recommend Spendrift to someone like you?
**Input:** 0 to 5 stars.

This is a lightweight NPS.
It belongs last so it is coloured by the rest of the session, not by the chrome alone.
4 to 5 can later unlock an App Store review prompt.
1 to 2 should offer the notes page ("what should we fix").

---

## Full catalog (more steps you can add)

Use these when you want a longer research pass, a one-shot TestFlight survey, or branching after a low score.
Do not dump all of them into the always-on in-app form.

### Acquisition follow-ups

**Question:** What convinced you to install?
**Input:** Single-select.

- Voice logging
- Statement import
- "It stays on my phone"
- Shortcuts / Action Button
- The look of the app
- Price / free to download
- Not sure

Ties to the YouTube hooks (voice, PDF populate, Action Button) and the privacy line.

**Question:** Which of these have you used before?
**Input:** Multi-select.

- Wallet / Money Manager
- YNAB or similar budget app
- Apple Wallet / Notes / a spreadsheet
- Nothing, this is my first tracker

Tells you the comparison set.
A spreadsheet refugee wants export.
A YNAB refugee wants budgets and guilt.
A "nothing" user wants the empty-state first transaction to feel obvious.

### Ledger structure

**Question:** How many pots of money do you need?
**Input:** Single-select.

- One account is enough
- A few accounts (cash, bank, card)
- Many accounts, with a clear primary
- I want net worth / assets too

The app already has multi-account, a primary account, and derived balances.
Shortcuts and widgets assume primary.
If "one account" wins, primary-account UX can stay hidden.
If "net worth" wins, you are being asked to become a different app.

**Question:** Are the default categories enough?
**Input:** Single-select.

- Yes
- I had to add my own
- I want a much bigger list
- I want to hide defaults I don't use
- Haven't looked

The seeded catalog is intentionally small.
Legacy installs had a larger set (Education, Entertainment, Baby, Investments, and so on).
This is the preference that decides whether to grow the seed, keep it tight, or add locale packs (the `localeAdditions` hook is empty today).

**Question:** Do you need a third type besides income and expense?
**Input:** Single-select.

- No
- Transfer between my own accounts
- Savings / goals
- Not sure

Transactions are only income or expense.
People who move money from checking to savings will currently distort both.

### Capture friction, one feature at a time

Only show the matching question if they claimed to use that method.

**Voice — How was speaking a transaction?**
0 to 5 stars.

**Voice — What was off?**
Single-select: amount, category, account, date, it just failed, nothing.

**Receipt — How was scanning a receipt?**
0 to 5 stars.

**Statement — How was importing a PDF?**
0 to 5 stars.

**Statement — What got in the way?**
Single-select: file type (PDF only), size, password-protected file, uncategorized rows, privacy toggle, it worked.

**SMS — How was setting up bank SMS?**
0 to 5 stars.

**SMS — Where did you stop?**
Single-select: never tried, Shortcuts was confusing, automation did not fire, parsing was wrong, it works.

These map onto real edges: 2 to 30 second voice clips, PDF-only 20 MB, password PDFs, imported rows landing uncategorized, six-step SMS automation, messages redacted on device then parsed.

### Surfaces people may not have found

**Question:** Which of these do you use?
**Input:** Multi-select.

- Transactions tab
- Accounts tab
- Categories tab
- Analytics tab
- Settings
- Widgets
- Live Activity / Dynamic Island while voice is running

If Categories and Analytics are rarely checked, those tabs are candidates to simplify, not to load with more.

**Question:** How does adding a transaction by typing feel?
**Input:** 0 to 5 stars.

The typed sheet is amount-in-the-hero, notes, date, income vs expense, account, category.
Amounts are whole numbers in the field.
This is the free forever path.
If this scores low, Pro cannot save the app.

### Notifications and chrome

**Question:** How do you feel about the daily reminder copy and timing?
**Input:** Single-select.

- Time is fine
- I want to pick days, not only time
- I want a monthly statement reminder only
- Turn it off by default

Today: daily time picker, default enabled, plus a day-2-of-month statement nudge in the scheduler.
Users cannot pick weekdays in Settings even though the underlying schedule already varies deep links by weekday.

**Question:** How do you feel about Spendrift's look?
Already asked as UI approval.
Optional split if UI stars are 0 to 2:

**Question:** What should change first?
Single-select: colours, typography, spacing / density, icons, dark / light, it feels like too much, it feels like too little.

There is a night-family onboarding / paywall and a ledger colour-wash.
A low UI score with "it feels like too much" is a different fix from "colours."

### Money and locale

**Question:** Is the currency display right for you?
**Input:** Single-select.

- Yes, my phone currency is correct
- I need to pick a currency in the app
- I need more than one currency
- I care about paise / cents, not rounded amounts

Lists can show decimals.
The Transactions header rounds to whole units after 10 transactions in the month.
Widgets show integer amounts.
This is a real consistency bug and a real localisation preference (INR-heavy audience vs everyone else).

### Trust and support

**Question:** If something breaks, what would you do?
**Input:** Single-select.

- Use this Feedback page
- Request a feature in Settings
- Email
- Leave an App Store review
- Delete the app
- Nothing

Tells you whether this page will actually be found, or whether you still need a more obvious entry (empty states, failed voice bar, paywall).

**Question:** How do you feel about anonymous usage analytics?
**Input:** Single-select.

- Fine
- I want a toggle
- I don't want any of it

PostHog and Sentry exist.
There is still no Settings toggle for `analyticsOptOut` / `diagnosticsOptOut`.
This is the preference that decides whether that toggle is a trust feature or unused chrome.

---

## Branching (keep the form short in production)

Always show:

1. UI approval
2. Found where
3. Why they opened it
4. Preferred capture
12. Recommend

Show only when relevant:

- Capture quality, if they have added a transaction.
- Per-feature accuracy, if they named a specific AI method.
- Privacy bargain, if they use or want AI capture.
- Reminders, if they are not a once-a-month importer.
- Outside-the-app setup, if they chose widget / Shortcut / SMS.
- Analytics follow-up, if they have opened Analytics or used the app more than a few days.
- Pro value, if they have seen a paywall, used an AI feature, or been around long enough to hit a quota.
- UI split, only if UI stars are 0 to 2.
- Missing piece, always, unless they already skipped to notes.

Anyone can hit **Skip to notes** at any time.
Do not block Next on later steps if they skipped an optional one.
A selected "Haven't used it" / "Not sure" is a complete answer.

---

## Notes / manual feedback page (skip destination)

Title stays **Feedback**.
Back returns to the form.
The primary action is Send, not Next.

Copy should make the two modes obvious:

- "Skip the questions and just write."
- Placeholder: thoughts, a bug, or a feature you want.

Keep screenshot attach.
That is how people report UI issues the star rating cannot describe.

If they already answered structured steps, send those answers with the note so a "voice is wrong" essay is attached to "I capture by speaking" and a 2-star accuracy score.

If they came here with no structured answers, that is still a valid submission.

---

## What this form should not try to be

- A substitute for PostHog.
  Do not ask "how many transactions did you create" or "which tab did you open last."
- A crash reporter.
  Sentry exists.
- A paywall.
  Asking about Pro is research, not a prompt to subscribe.
- A 25-step interrogation.
  If you want all of the catalog, run it once on TestFlight, not in Settings for every user.

---

## Suggested submit payload (for when this is built)

Per submission, keep:

- App version
- Step answers (question id, type, value)
- Whether they used skip-to-notes
- Notes text / screenshot flag
- Locale / region (not a name, not an email unless Mail is the transport)

That is enough to slice "Reddit users who want budgets" vs "YouTube users who live on voice" without turning Feedback into an account system.

---

## Short version of the first ship

| # | Question | Input |
|---|---|---|
| 1 | How does the app look and feel? | 0 to 5 stars |
| 2 | Where did you find Spendrift? | Facebook, Reddit, Instagram, Other |
| 3 | What are you mainly using it for? | Multi-choice |
| 4 | How do you prefer to add a transaction? | Multi-choice |
| 5 | When you add something, how often is it right? | 0 to 5 stars |
| 6 | How do you feel about AI leaving the device? | Multi-choice |
| 7 | How often do you want to log? | Multi-choice |
| 8 | Widget, Shortcuts, Action Button, SMS? | Multi-select |
| 9 | Does Analytics help? | 0 to 5 stars, then one choice |
| 10 | If we built one thing next? | Multi-choice |
| 11 | Are the AI features worth paying for? | 0 to 5 stars, then one choice |
| 12 | Would you recommend Spendrift? | 0 to 5 stars |

Plus Skip to notes, available on every step.

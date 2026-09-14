# Feedback page - multi-step form

Proposal only.
No implementation in this document.

This ships to **live App Store users**, not a TestFlight-only survey.
Keep it short enough that someone who opened Feedback because something broke still finishes it.

Feedback becomes its own page in the app, not a mail sheet bolted onto Settings.
The last step is always a notes screen (thoughts, bugs, feature requests).
**Skip to notes** on earlier steps jumps straight to that final step.

---

## Page chrome

Every step uses the same navigation bar:

- **Back** on the top left. Previous step, or dismiss on step 1.
- **"Feedback"** centered on every step, including notes.
- **Next** on the top right. Disabled until the step has an answer.

**Skip to notes** sits below the question (text button or tertiary action).
It jumps straight to free-text feedback.
Do not force people who already know what they want to say through the form.

Next advances through the survey; the final step uses **Submit** instead of Next.
Back from the notes step returns to the previous survey step unless they already sent.

---

## Input rules

Only two input types on structured steps:

1. **0 to 5 stars** - quality, accuracy, recommendation.
   0 is valid ("haven't used this" / "doesn't work for me").
2. **Multi-choice** - single-select unless marked multi-select.
   Always include **Haven't used it**, **Not sure**, or **Other** where honest.

One question per step on survey steps 1 to 8.
Free text only on the final notes step (step 9).

---

## Live form (8 survey steps + notes)

Ship this set.
Every question maps to a real product surface you can improve from the answer.

### 1. UI approval

**Question:** How does the app look and feel?
**Input:** 0 to 5 stars.

Visual and interaction quality only: colour wash, lists, sheets, typography.
Not "do I like finance apps."

---

### 2. Found where

**Question:** Where did you find Spendrift?
**Input:** Single-select.

- Reddit
- YouTube
- App Store
- Other

These four match how installs actually arrive today.
YouTube is the proven channel; Reddit is the secondary trust layer; App Store is organic search and browse.
**Other** will still catch friends, Instagram, and anything else without diluting the main buckets.

---

### 3. Shortcuts and Explore

**Question:** Have you looked at the shortcuts Spendrift offers?
**Input:** Single-select.

- Yes, I opened **Explore** or saw them in onboarding
- I saw them but didn't add any
- I added at least one shortcut
- I didn't know they existed

**Why:** Onboarding page 2 and Settings → Explore exist almost entirely to push three iCloud shortcuts:

1. **Voice Record Expense** - speak a transaction
2. **Log Expense Amount** - type an amount without opening the app
3. **Log Transaction Message** - bank SMS automation (six-step setup in Shortcuts)

If most people pick "didn't know they existed," discovery is broken, not the shortcuts themselves.
If they opened Explore but never added one, the friction is in the add flow or the value prop, not awareness.

---

### 4. Which shortcuts did you add?

**Question:** Which of these did you set up?
**Input:** Multi-select.

Show only if step 3 was **I added at least one shortcut** or **I saw them but didn't add any** (still useful to see what they considered).

- Voice Record Expense
- Log Expense Amount
- Bank SMS automation
- Home screen widget
- None of these

**Why:** Tells you which shortcut hook actually converts.
Voice is the YouTube hero; typed amount is the silent power-user path; SMS is the highest-setup, highest-payoff automation.
Widget is separate but lives in the same "outside the app" bucket.

If step 3 was **I didn't know they existed**, skip this step.

---

### 5. How do you add transactions?

**Question:** How do you actually log spending in Spendrift?
**Input:** Multi-select.

- Type in the app
- Speak (in app or via shortcut)
- Scan a receipt
- Import a bank statement (PDF)
- Bank SMS
- Widget or Shortcut only
- Haven't logged one yet

**Why:** This is behaviour, not preference.
PostHog can corroborate it, but self-report still catches intent vs habit ("I want voice but I always type").

If **Haven't logged one yet**, skip steps 6 and 7 and go to step 8 (recommend), then step 9 (notes).

---

### 6. Capture accuracy

**Question:** When you log something, how often does Spendrift get it right?
**Input:** 0 to 5 stars.

Show only if step 5 was not **Haven't logged one yet**.

**Why:** One score for the capture path they actually use.
Covers manual typing, voice parsing, receipt scan, PDF rows, and SMS parsing without a separate screen per feature.

Optional branch (only if they rated 0 to 2): one follow-up step.

**Question:** What was wrong most often?
**Input:** Single-select.

- Wrong amount
- Wrong category
- Wrong account
- It failed / I had to re-enter
- Not sure

---

### 7. AI features and Pro

**Question:** Have you tried any of Spendrift's AI features?
**Input:** Multi-select.

- Voice capture
- Receipt scan
- Bank statement import
- Bank SMS import
- None of these

If they picked at least one AI feature, show on the next screen (same step or one more):

**Question:** How was that feature?
**Input:** 0 to 5 stars.

Then:

**Question:** How do you feel about Pro?
**Input:** Single-select.

- Worth paying for
- Free limits are enough
- I don't want a subscription
- I already subscribe
- Haven't hit the paywall

If they picked **None of these**, skip the star rating and only ask the Pro question if they have seen a paywall (otherwise skip step 7 Pro follow-up entirely and go to step 8, then notes).

**Why:** Pro gates only the four AI calls (10 voice / 30 SMS / 5 receipts / 1 statement per month free).
This ties feedback to the paid surface without turning the form into a paywall.

---

### 8. Would you recommend it

**Question:** Would you recommend Spendrift to someone like you?
**Input:** 0 to 5 stars.

Lightweight NPS, last so it reflects the whole session.
4 to 5 can later trigger an App Store review prompt.
0 to 2 can pre-fill the notes placeholder with "What should we fix?"

---

### 9. Notes (final step)

**Question:** Anything else you want to share?
**Input:** Free text (optional) plus optional screenshot.

- Placeholder: thoughts, a bug, or a feature you want.
- Primary action is **Submit**, not Next.
- Notes can be empty if the survey answers alone are enough.
- **Skip to notes** on any earlier step lands here with prior answers preserved.

On submit, the full survey (steps 1 to 8 answers plus notes) is sent to Supabase keyed by `device_id`.

---

## Branching summary

| Step | Always show? |
|---|---|
| 1 UI approval | Yes |
| 2 Found where | Yes |
| 3 Shortcuts / Explore | Yes |
| 4 Which shortcuts added | If step 3 ≠ "didn't know" |
| 5 How they log | Yes |
| 6 Capture accuracy | If step 5 ≠ "haven't logged" |
| 6b What was wrong | If step 6 is 0 to 2 stars |
| 7 AI + Pro | Yes, but star rating only if they used AI |
| 8 Recommend | Yes |
| 9 Notes | Yes (always last; Submit) |

**Skip to notes** available on steps 1 to 8 (jumps to step 9).

Typical path: **8 to 10 screens** depending on answers, always ending on notes.
Worst case with the accuracy branch: **11** (includes notes).
Target median: **9**.

---

## What we dropped (and why)

These were in the earlier draft but cut for live users:

- **Why they opened the app** - too abstract; capture behaviour (step 5) is sharper.
- **Privacy bargain** - important strategically, but not actionable in a short form; use notes or a one-off campaign if needed.
- **Reminders** - Settings already exposes the toggle; PostHog can show opt-out.
- **Analytics tab** - usage is measurable; roadmap voting belongs in notes or a future pulse, not every submission.
- **"Build one thing next"** - duplicates notes; people with strong opinions will skip to write anyway.
- **Full catalog / 25-step variants** - not for production.

---

## What this form should not try to be

- A substitute for PostHog.
  Do not ask "how many transactions" or "which tab last."
- A crash reporter.
  Sentry exists.
- A paywall.
  Pro questions are research, not a subscribe prompt.
- A long survey.
  If a question does not map to a feature you can fix or a funnel you can measure, cut it.

---

## Submit payload (Supabase)

Every submission is keyed by a single **`device_id`**: a Keychain-backed UUID from `DeviceIdentity.current`, generated on first launch per device and independent of analytics opt-out.

The same `device_id` is attached everywhere else:

- **PostHog** - registered super property on every event (anonymous `distinct_id` unchanged)
- **Sentry** - user id on crashes and errors
- **Supabase** - primary key for joining feedback to product and crash data

Per submission row:

- `device_id` (UUID string, required)
- `app_version` (marketing version + build)
- `answers` (JSON: question id, type, value for steps 1 to 8)
- `skipped_to_notes` (bool: did they jump past remaining survey steps)
- `notes` (text, optional)
- `has_screenshot` (bool)
- `locale` / region (no name, no email)

No auth, no PII. The id is a random UUID only.

Example slices this enables:

- YouTube installs (`found_where`) who never opened Explore, joined via `device_id` to their PostHog funnel
- Reddit users who added voice shortcut but rate capture 1 to 2 stars, with Sentry errors on the same `device_id`
- App Store organic users who only type in-app and never tried AI

---

## Quick reference

| # | Question | Input |
|---|---|---|
| 1 | How does the app look and feel? | 0 to 5 stars |
| 2 | Where did you find Spendrift? | Reddit, YouTube, App Store, Other |
| 3 | Have you looked at the shortcuts Spendrift offers? | Single-select |
| 4 | Which shortcuts did you set up? | Multi-select (conditional) |
| 5 | How do you actually log spending? | Multi-select |
| 6 | How often does logging get it right? | 0 to 5 stars (conditional) |
| 6b | What was wrong most often? | Single-select (if 0 to 2 stars) |
| 7 | AI features tried + Pro feeling | Multi-select + stars + single-select |
| 8 | Would you recommend Spendrift? | 0 to 5 stars |
| 9 | Anything else you want to share? | Free text + screenshot (Submit) |

Plus **Skip to notes** on steps 1 to 8.

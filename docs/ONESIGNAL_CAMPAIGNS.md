# OneSignal campaign tags

Consult this file when you want to send a remote push to a kind of user.

Tags are written by the iOS app as OneSignal Data Tags (`sd_*`).
Build a segment in the OneSignal dashboard, then send from there.
Always AND the segment with subscribed users.
Denied permission cannot be fixed by a push.

Values are strings.
Booleans are `true` / `false`.
Ints are unpadded (`3`, not `03`).
Dates are `YYYY-MM-DD` in the device's local calendar.

Do not put notes, amounts, names, or emails in a tag.

Learning tags (`sd_learning_*`) are not written.
That surface does not exist yet.

Current push paths the app will open: `/feedback`, `/explore`.
Unknown paths are ignored.

Cap marketing pushes at one per week per device.
Trial-ending and quota-refill style messages can sit outside that cap.

---

## Tag catalog

| Tag | Values | What it means | Typical campaign use |
| --- | --- | --- | --- |
| `sd_onboarding_done` | `true` / `false` | Finished the current onboarding carousel | Exclude first-open people from feature tours. Nudge people stuck on onboarding. |
| `sd_has_transaction` | `true` / `false` | At least one ledger row, including typed shortcuts | Activation vs catch-up. Do not pitch charts to people with an empty ledger. |
| `sd_tx_count_bucket` | `0`, `1`, `2_5`, `6_20`, `21_plus` | Habit strength without a raw count | Charts education starts at `2_5`. Power-user copy at `21_plus`. |
| `sd_used_manual` | `true` / `false` | Saved a typed-in-app transaction | "Try voice" education. |
| `sd_used_voice` | `true` / `false` | At least one voice capture that saved | Inverse of "never tried voice". Winback if they used AI. |
| `sd_used_sms` | `true` / `false` | At least one SMS import row | Exclude from SMS setup nudges. |
| `sd_used_pdf` | `true` / `false` | Saved a statement import | Statement education. |
| `sd_used_receipt` | `true` / `false` | Saved a receipt scan | Receipt education. |
| `sd_used_typed_shortcut` | `true` / `false` | Logged from the amount shortcut (app closed) | They already found a capture path. Exclude from Explore "add a shortcut". |
| `sd_seen_explore` | `true` / `false` | Opened the Explore carousel | Never-seen-Explore vs saw-but-did-not-add. |
| `sd_explore_shortcut_added` | `true` / `false` | Tapped **Add shortcut** in Explore | Intent to add, not proof the iCloud shortcut exists. |
| `sd_seen_analytics` | `true` / `false` | Turned the Transactions charts toggle on | Charts education. |
| `sd_plan` | `free`, `trial`, `pro`, `lapsed` | Current StoreKit state | Pricing, trial ending, winback. Omitted until StoreKit answers, so a cold start will not briefly look free. |
| `sd_trial_ends_on` | `YYYY-MM-DD` | Present only while `sd_plan` is `trial` | Trial-ending remote push. The tag is removed after the trial ends. |
| `sd_quota_voice` | remaining credits | Voice credits left this month | "You are almost out". Combine with `sd_plan` != `pro`. |
| `sd_quota_sms` | remaining | SMS credits left | Same. |
| `sd_quota_receipt` | remaining | Receipt credits left | Same. |
| `sd_quota_pdf` | remaining | Statement credits left | Same. |
| `sd_quota_exhausted_any` | `true` / `false` | Any free-tier feature is at 0, and they are not Pro | Broad "hit the wall" segment. Always false for Pro. |
| `sd_hit_quota_voice` | `true` / `false` | Hit the voice wall at least once this calendar month | Clears on month rollover. |
| `sd_quota_hits_30d` | `0`–`99` | How many times they hit any quota wall in 30 days | "Constantly out of credits" is `>= 2`. |
| `sd_notif_status` | `not_determined` / `denied` / `authorized` / `provisional` / `ephemeral` | System permission | Do not bother targeting `denied`. They will not receive the push. |
| `sd_last_active_on` | `YYYY-MM-DD` | Last time the app came to the foreground | Inactive audiences without a PostHog job. |
| `sd_days_since_install` | `0`–N | Whole days since first launch on this install | Day-3 / day-7 drips. |
| `sd_app_version` | `1.4.1` | Marketing version, no build number | "Please update". |
| `sd_ios_version` | `18.5` | `UIDevice` system version | Support targeting. |
| `sd_locale` | `en_IN` | `Locale.current.identifier` | Copy language later. |

`sd_last_active_on` plus `sd_has_transaction` is enough for "downloaded, opened once, never came back".

---

## How to build a segment

In OneSignal:

1. Audience -> Segments -> New segment.
2. First filter: First Session / subscribed users (the people who can actually receive a push).
3. Add User Tag filters for the `sd_*` keys below.
4. Numeric tags (`sd_days_since_install`, `sd_quota_*`, `sd_quota_hits_30d`) compare as numbers if you use greater-than / less-than.
5. Date tags compare lexicographically because they are `YYYY-MM-DD`. "Older than 2 days" means `sd_last_active_on` is less than today's date minus two days.

Name the segment after the campaign, for example `explore_never_seen_v1`.

Every payload still needs a `path` and a `campaign` label.
The app only routes `/feedback` and `/explore` today.

---

## Recipes

Copy is yours.
The filters are the contract.

### Never seen Explore

People who finished onboarding and never opened the carousel.

- `sd_seen_explore` is `false`
- `sd_onboarding_done` is `true`
- `sd_days_since_install` >= `2`
- Exclude `sd_used_typed_shortcut` is `true`
- Exclude `sd_used_sms` is `true`

Path: `/explore`
Campaign: `explore_never_seen_v1`

They already have a capture path if the typed shortcut or SMS import worked.

### Saw Explore, added nothing

- `sd_seen_explore` is `true`
- `sd_explore_shortcut_added` is `false`
- `sd_used_voice` is `false`
- `sd_used_sms` is `false`
- `sd_used_typed_shortcut` is `false`

Path: `/explore`
Campaign: `explore_saw_not_added_v1`

### Free or trial, constantly out of credits

- `sd_plan` is `free` or `trial`
- `sd_quota_hits_30d` >= `2`
- `sd_quota_exhausted_any` is `true`

Tighter variant:

- `sd_quota_voice` is `0`
- `sd_used_voice` is `true`
- `sd_plan` is not `pro`

Path: `/explore` until a `/pro` route exists.
Campaign: `quota_wall_pro_v1`

Send at most once per week.
This audience is already frustrated.

### Trial ending, still using the app

- `sd_plan` is `trial`
- `sd_trial_ends_on` within 2 days of today
- `sd_has_transaction` is `true`

Campaign: `trial_ending_remote_v1`

Local trial reminders already cover people who leave the app allowed to schedule notifications.
Use this for people who backgrounded and will miss the local request.

### Trial ended, lapsed, used AI

- `sd_plan` is `lapsed`
- Any of `sd_used_voice`, `sd_used_sms`, `sd_used_receipt`, `sd_used_pdf` is `true`

Campaign: `pro_winback_v1`

Do not pitch Pro to people who never used an AI feature.

### Never seen Analytics charts

- `sd_seen_analytics` is `false`
- `sd_has_transaction` is `true`
- `sd_tx_count_bucket` is `2_5` or `6_20` or `21_plus`

Path: `/explore` until `/analytics` exists.
Campaign: `analytics_never_seen_v1`

Do not send this to `sd_tx_count_bucket` `0` or `1`.
Charts of nothing are a bad first impression.

### Opened once, no transaction, quiet

- `sd_has_transaction` is `false`
- `sd_days_since_install` between `3` and `7`
- `sd_last_active_on` older than 2 days

Campaign: `inactive_no_activation_d3_v1`

Ask them to log one expense.
There is no create-sheet push path yet, so this currently just opens the app.

### Activated, then disappeared

- `sd_has_transaction` is `true`
- `sd_last_active_on` older than 14 days
- Optional: `sd_plan` is not `pro`

Campaign: `inactive_churn_d14_v1`

Catch-up, not a feature tour.

### Installed, never finished onboarding

- `sd_onboarding_done` is `false`
- `sd_days_since_install` >= `1`

Campaign: `inactive_onboarding_v1`

Onboarding already shows on next open.
This push is only "come back".

### Manual only, never voice

- `sd_used_manual` is `true`
- `sd_used_voice` is `false`

Path: `/explore`
Campaign: `try_voice_v1`

Do not send this to people you know denied the microphone.
That signal is not a OneSignal tag today.

### Has transactions, never SMS

- `sd_has_transaction` is `true`
- `sd_used_sms` is `false`

Path: `/explore`
Campaign: `try_sms_v1`

### Has transactions, never receipt

- `sd_has_transaction` is `true`
- `sd_used_receipt` is `false`

Campaign: `try_receipt_v1`

### Has transactions, never PDF

- `sd_has_transaction` is `true`
- `sd_used_pdf` is `false`

Campaign: `try_statement_v1`

### Used voice in-app, never added the Siri shortcut

- `sd_used_voice` is `true`
- `sd_explore_shortcut_added` is `false`

Path: `/explore`
Campaign: `voice_to_siri_v1`

### Feedback

- `sd_days_since_install` >= `7`
- `sd_has_transaction` is `true`

Path: `/feedback`
Campaign: `feedback_nudge_v1`

Send once.
"Never submitted feedback" is a PostHog fact, not a tag.
Exclude people you already reached for this campaign from the OneSignal sent history.
Do not mix this audience with Explore or Pro nags in the same week.

---

## What tags cannot do

Absence over a long window that is not "last opened on" still belongs in PostHog, then a send to specific `device_ids`.

Examples that tags are weak at:

- Installed 7 days ago and never created a first transaction, if they kept opening the app (use `sd_has_transaction` plus `sd_days_since_install` instead).
- Never submitted feedback (no `sd_feedback_submitted` tag).
- Widget installed on the Home Screen (no reliable tag).
- Microphone denied (no tag).

Do not send feature tours to dormant users (`sd_last_active_on` older than 30 days).
Do not send Explore education to people with `sd_onboarding_done` is `false`.
Do not spend sends on `sd_notif_status` is `denied`.

---

## Suggested drip for a new install

Skip the send if the success tag is already true.
One education push per week unless the message is transactional.

| Day | Condition | Campaign |
| --- | --- | --- |
| 0 | No push | Permission is requested in Settings, not at launch |
| 3 | `sd_has_transaction` is `false` | `inactive_no_activation_d3_v1` |
| 5 | `sd_has_transaction` is `true` and `sd_seen_explore` is `false` | `explore_never_seen_v1` |
| 8 | has transaction, `sd_used_voice` is `false` | `try_voice_v1` |
| 12 | has transaction, `sd_used_sms` is `false` | `try_sms_v1` |
| 16 | `sd_tx_count_bucket` is `2_5` or higher, `sd_seen_analytics` is `false` | `analytics_never_seen_v1` |
| 21 | `sd_quota_hits_30d` >= `1`, not Pro | `quota_wall_pro_v1` |
| 30 | still free, active, never asked for feedback | `feedback_nudge_v1` |

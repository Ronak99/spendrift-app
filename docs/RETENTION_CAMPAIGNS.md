# Retention campaigns

How to turn the `sd_*` tags into a retention program without spamming a 3-person install base into revoking permission.

This document answers four things:

1. Whether you build one campaign or many, and one audience or many.
2. The five constraints in Spendrift's own implementation that decide which audiences are actually buildable.
3. A segment catalog with exact filter JSON you can paste into the API.
4. A copy library: title, subtitle, and body for every scenario, written to move a specific metric.

Read `ONESIGNAL_CAMPAIGNS.md` for the tag contract and `TRACKING_AND_AUDIENCES.md` for what PostHog knows.
This document is the layer on top: how to combine those tags into a program.

---

## 0. The short answer

**Do not create a campaign per permutation.**
**Do not create a segment per permutation either.**

Permutations are combinatorial.
Three booleans is eight audiences.
Six booleans is sixty-four.
You will never write sixty-four pieces of good copy, and a user who matches five of them gets five pushes.

Use four objects, each with a different lifetime:

| Object | How many | Lifetime | What it is for |
| --- | --- | --- | --- |
| **Segment** | ~14, fixed | Months | A durable, named audience you will reuse and want a subscriber count for |
| **Template** | 1 per campaign family | Months | Reusable copy with Liquid personalization |
| **Message** | 1 per send | One send | The actual dispatch, named `<campaign>_<yyyymmdd>` |
| **Journey** | 1 | Months | The day-N onboarding drip, where timing is relative to each user's own install |

The permutations live in **message-level filters**, not in segments.
Promote a filter combination to a named segment only when you have sent it three times and want to track its size over months.

The thing that actually drives retention is not the number of audiences.
It is the **priority ladder** in section 3, which guarantees each user is in exactly one bucket per week.

---

## 1. Three targeting primitives, and when to use each

Spendrift has three ways to describe a user, and picking the wrong one is the most common failure.

### Primitive A: `sd_*` tags describe **current state**

Written by `AudienceTags.swift` on foreground, and after state changes, via `OneSignal.User.addTags`.

Good for: has used voice, plan is trial, credits remaining, transaction bucket, onboarding done.

Bad for: anything involving elapsed time.
See section 2.1.

### Primitive B: OneSignal `first_session` / `last_session` describe **time**

Computed by OneSignal's servers from the subscription record.
They do not depend on the app writing anything.

```json
{ "field": "first_session", "relation": ">", "hours_ago": "72" }
{ "field": "last_session",  "relation": ">", "hours_ago": "336" }
```

`first_session > 72 hours ago` means "installed more than 3 days ago".
`last_session > 336 hours ago` means "has not opened the app in 14 days".

**Always use these for time. Never use `sd_days_since_install` or `sd_last_active_on`.**
Section 2.1 explains why.

### Primitive C: PostHog cohorts describe **absence of an event over a window**

Things no tag can express: never submitted feedback, hit the voice wall on 3 separate days, denied the microphone.

Resolve `distinct_id` to `device_id` through `public.devices.posthog_id`, then call the campaign API with `audience.kind = "devices"`.

### The rule

> State goes in tags.
> Time goes in session filters.
> Absence goes in PostHog.

A well-built segment is usually two or three tag filters (state) AND one session filter (time).

---

## 2. Five constraints you must design around

These come from reading the shipped code, not from OneSignal's docs.
Every one of them silently breaks a segment that looks correct.

### 2.1 `sd_days_since_install` freezes for the exact users you want to reach

`AudienceTags.sync()` runs on launch, foreground, and permission grant.
It writes `daysSinceInstall` computed **at that moment**.

So a user who installs, opens once, and never returns keeps `sd_days_since_install = 0` forever.

This means the existing recipe in `ONESIGNAL_CAMPAIGNS.md`:

```
sd_has_transaction = false AND sd_days_since_install between 3 and 7
```

**matches nobody who actually churned.**
It only matches people who are still opening the app on day 3 to 7, which is the opposite audience.

The same applies to `sd_last_active_on`.
It is accurate as a record of the last foreground, but it is a lexicographic date string, so "older than 14 days" requires you to hardcode a date that rots the next morning.

**Fix:** use `first_session` and `last_session` with `hours_ago`.
They are server-side and self-updating.

Every time-based recipe in this document uses session filters for this reason.

### 2.2 `sd_plan` is absent, not `free`, while StoreKit is still answering

```swift
case .unknown:
    plan = nil   // sd_plan is omitted entirely
```

A filter of `sd_plan != pro` will not reliably match a user whose tag is missing.

**Fix:** write the positive form.
Use `sd_plan = free` OR `sd_plan = trial` instead of `sd_plan != pro`.
This is deliberate in the code so a cold start never briefly looks like a free user, and your segments must respect it.

### 2.3 `sd_tx_count_bucket` is an enum string, so you cannot compare it numerically

Values are `0`, `1`, `2_5`, `6_20`, `21_plus`.

`sd_tx_count_bucket > 20` does nothing.
"More than 20 transactions" is exactly `sd_tx_count_bucket = 21_plus`.

For "6 or more", you need two filters OR'd together:

```json
[
  { "field": "tag", "key": "sd_tx_count_bucket", "relation": "=", "value": "6_20" },
  { "operator": "OR" },
  { "field": "tag", "key": "sd_tx_count_bucket", "relation": "=", "value": "21_plus" }
]
```

This also means **you cannot personalize copy with a raw transaction count**.
See section 7.3 for what to add if you want that.

### 2.4 Quota tags start at zero for new users without notifications

```swift
remaining(feature) = max(0, monthlyAllowance(feature) - used)
```

In the signup month, `monthlyAllowance` is 0 until the user grants notification permission, then the full free quota.
From the next month on, it is always the full free quota.

| Feature | Free monthly | Max `sd_quota_*` |
| --- | --- | --- |
| Voice | 10 | 10 |
| SMS | 30 | 30 |
| Receipt | 5 | 5 |
| Statement | 1 | 1 |

`sd_quota_voice = 0` therefore also matches new users who declined notifications and have never used voice.
Pair it with `sd_used_voice = true` when you mean "hit the wall".

Your live segment `Voice Quota Less Than 18` filters `sd_quota_voice < 18`.
A free user who has never touched voice sits at `10`.
**That segment matches essentially every free user, including people who have never used the feature it advertises.**
It is an accidental "everyone" segment wearing a specific name.

"Almost out of voice" is `sd_quota_voice <= 2` AND `sd_used_voice = true`.
"Hit the wall" is `sd_quota_voice = 0`.

### 2.5 Only `/feedback` and `/explore` exist as push destinations

```swift
enum AppRoute: String, CaseIterable, Hashable {
    case feedback = "/feedback"
    case explore = "/explore"
}
```

The backend enforces the same allowlist in `APP_PUSH_PATHS`.

This is a hard ceiling on copy quality.
A push that says "see your spending charts" and lands on the Explore carousel is a broken promise, and a broken promise is worse for retention than no push at all.

**Until `/pro` and `/analytics` exist, do not write monetization or charts copy.**
Section 9 lists the routes to add and in what order.

---

## 3. The priority ladder

This is the single most important section.

A user with 25 transactions who has never opened Explore, never used voice, never imported SMS, and is running low on credits matches **four** education segments at once.
Without a ladder they get four pushes, and then they turn notifications off.
`device_notifications.permission_status = denied` is effectively irreversible from inside the app.

So: each tier **excludes every tier above it**.
Evaluate top down, send from the first tier the user matches, stop.

| Tier | Name | Condition | Cap |
| --- | --- | --- | --- |
| 0 | **Unreachable** | `sd_notif_status = denied` | Never send |
| 1 | **Transactional** | Trial ending, quota refilled | Outside the weekly cap |
| 2 | **Onboarding stalled** | `sd_onboarding_done = false` | 1 total, then stop |
| 3 | **Never activated** | `sd_has_transaction = false` | 2 total, then stop |
| 4 | **Dormant** | `last_session > 14 days` | 1 per 30 days |
| 5 | **Education** | Active, activated, missing a feature | 1 per 7 days |
| 6 | **Depth and monetization** | Active, habitual, hit a wall | 1 per 7 days |
| 7 | **Feedback** | Habitual, 7+ days in | 1 ever |

Tier 5 is where all the permutations the user asked about live.
Within tier 5, pick **one** message using the ordering in section 6.

### Why this ordering

Tiers 2 and 3 come before education because a feature tour is meaningless to someone with an empty ledger.
Tier 4 comes before education because a dormant user needs a reason to open the app, not a lesson about a feature.
Tier 7 is last because asking for feedback from someone who has not built the habit produces noise.

### Implementing the ladder

OneSignal has no native "exclude anyone who matched a higher segment".
You get it two ways:

1. **`excluded_segments` on the message.**
   Every tier-5 send excludes `ladder_not_activated` and `ladder_dormant`.
   This is the simple approach and works today.
2. **Enable app-level frequency capping** in OneSignal settings, set to 1 message per 7 days.
   This is the safety net that catches ladder mistakes.
   Mark trial-ending and quota-refill messages as exempt.

Do both.
The ladder is intent, the cap is insurance.

---

## 4. Segment catalog

Fourteen segments, named by tier.
Each is given as the exact `filters` array for `POST /apps/{id}/segments`.

Every segment includes `sd_notif_status = authorized`.
OneSignal will not deliver to an unsubscribed device anyway, but the tag keeps your subscriber counts honest and keeps Supabase, PostHog, and OneSignal speaking the same vocabulary.

### Tier 2: onboarding

**`ladder_onboarding_stalled`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_onboarding_done", "relation": "=", "value": "false" },
  { "field": "first_session", "relation": ">", "hours_ago": "24" }
]
```

### Tier 3: activation

**`ladder_not_activated`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_onboarding_done", "relation": "=", "value": "true" },
  { "field": "tag", "key": "sd_has_transaction", "relation": "=", "value": "false" },
  { "field": "first_session", "relation": ">", "hours_ago": "72" }
]
```

### Tier 4: dormancy

**`ladder_dormant_activated`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_has_transaction", "relation": "=", "value": "true" },
  { "field": "last_session", "relation": ">", "hours_ago": "336" }
]
```

**`ladder_dormant_deep`** (30 days, one last try)

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "last_session", "relation": ">", "hours_ago": "720" }
]
```

Past 60 days, stop.
Sends to dead installs cost money and depress every rate you measure.

### Tier 5: education

All education segments share a base: reachable, activated, and active in the last 14 days.
The `last_session < 336` guard is what stops feature tours reaching dormant users.

**`edu_manual_only_no_voice`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_has_transaction", "relation": "=", "value": "true" },
  { "field": "tag", "key": "sd_used_voice", "relation": "=", "value": "false" },
  { "field": "last_session", "relation": "<", "hours_ago": "336" }
]
```

**`edu_no_bank_import`** (never used SMS or statement import)

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_has_transaction", "relation": "=", "value": "true" },
  { "field": "tag", "key": "sd_used_sms", "relation": "=", "value": "false" },
  { "field": "tag", "key": "sd_used_pdf", "relation": "=", "value": "false" },
  { "field": "last_session", "relation": "<", "hours_ago": "336" }
]
```

**`edu_no_receipt`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_has_transaction", "relation": "=", "value": "true" },
  { "field": "tag", "key": "sd_used_receipt", "relation": "=", "value": "false" },
  { "field": "last_session", "relation": "<", "hours_ago": "336" }
]
```

**`edu_explore_never_seen`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_seen_explore", "relation": "=", "value": "false" },
  { "field": "tag", "key": "sd_onboarding_done", "relation": "=", "value": "true" },
  { "field": "tag", "key": "sd_has_transaction", "relation": "=", "value": "true" },
  { "field": "last_session", "relation": "<", "hours_ago": "336" }
]
```

**`edu_explore_saw_not_added`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_seen_explore", "relation": "=", "value": "true" },
  { "field": "tag", "key": "sd_explore_shortcut_added", "relation": "=", "value": "false" },
  { "field": "tag", "key": "sd_used_typed_shortcut", "relation": "=", "value": "false" },
  { "field": "last_session", "relation": "<", "hours_ago": "336" }
]
```

**`edu_voice_no_siri`** (uses voice in-app, never added the shortcut)

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_used_voice", "relation": "=", "value": "true" },
  { "field": "tag", "key": "sd_explore_shortcut_added", "relation": "=", "value": "false" },
  { "field": "last_session", "relation": "<", "hours_ago": "336" }
]
```

### Tier 6: depth and monetization

**`depth_habitual_no_explore`** (the ">20 transactions, never opened Explore" case)

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_tx_count_bucket", "relation": "=", "value": "21_plus" },
  { "field": "tag", "key": "sd_seen_explore", "relation": "=", "value": "false" },
  { "field": "last_session", "relation": "<", "hours_ago": "336" }
]
```

**`quota_voice_nearly_out`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_used_voice", "relation": "=", "value": "true" },
  { "field": "tag", "key": "sd_quota_voice", "relation": "<", "value": "3" },
  { "field": "tag", "key": "sd_plan", "relation": "=", "value": "free" },
  { "operator": "OR" },
  { "field": "tag", "key": "sd_plan", "relation": "=", "value": "trial" }
]
```

Note the positive plan form, per constraint 2.2.

**`quota_wall_repeat`** (genuinely "constantly out of credits")

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_quota_hits_30d", "relation": ">", "value": "1" },
  { "field": "tag", "key": "sd_quota_exhausted_any", "relation": "=", "value": "true" }
]
```

`sd_quota_exhausted_any` is forced to `false` for Pro users in code, so this cannot leak to subscribers.

**`pro_trial_ending`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_plan", "relation": "=", "value": "trial" },
  { "field": "tag", "key": "sd_has_transaction", "relation": "=", "value": "true" }
]
```

Add `sd_trial_ends_on = <the date 2 days out>` at send time.
The tag is removed when the trial ends, so the segment self-cleans.

**`pro_winback_used_ai`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_plan", "relation": "=", "value": "lapsed" },
  { "field": "tag", "key": "sd_used_voice", "relation": "=", "value": "true" },
  { "operator": "OR" },
  { "field": "tag", "key": "sd_used_sms", "relation": "=", "value": "true" },
  { "operator": "OR" },
  { "field": "tag", "key": "sd_used_receipt", "relation": "=", "value": "true" },
  { "operator": "OR" },
  { "field": "tag", "key": "sd_used_pdf", "relation": "=", "value": "true" }
]
```

Never pitch Pro to someone who never used an AI feature.
They have no idea what they would be buying.

### Tier 7: feedback

**`feedback_eligible`**

```json
[
  { "field": "tag", "key": "sd_notif_status", "relation": "=", "value": "authorized" },
  { "field": "tag", "key": "sd_has_transaction", "relation": "=", "value": "true" },
  { "field": "first_session", "relation": ">", "hours_ago": "168" },
  { "field": "last_session", "relation": "<", "hours_ago": "336" }
]
```

"Never submitted feedback" is not a tag.
Exclude previously reached devices from OneSignal's sent history, or add `sd_feedback_submitted`.

---

## 5. The permutations you asked for

Each of these is a **message-level filter**, not a new segment, until you have sent it three times.

### 5.1 Downloaded, never created a voice transaction

Split this in two.
They are different people and need opposite copy.

**5.1a Never activated at all.**
No transactions of any kind.
Use `ladder_not_activated` (tier 3).
Do not mention voice.
Someone with an empty ledger does not need a feature, they need a first row.

**5.1b Activated, but types everything.**
Use `edu_manual_only_no_voice` (tier 5).
Optionally tighten with `sd_used_manual = true` so you are talking to a proven typer.

> Sending "try voice" to 5.1a is the single most common retention mistake in this taxonomy.

### 5.2 Uses voice, but never imported bank transactions

Base segment `edu_no_bank_import`, plus:

```json
{ "field": "tag", "key": "sd_used_voice", "relation": "=", "value": "true" }
```

They have already accepted that AI logs their spending.
The pitch is not "AI is good", it is "you are doing one at a time, this does a hundred".

Two sub-variants worth splitting, because the setup cost differs enormously:

| Variant | Extra filter | Why separate |
| --- | --- | --- |
| Never SMS | `sd_used_sms = false` | Requires a Shortcuts automation. High setup, highest payoff. |
| Never statement | `sd_used_pdf = false` | One file drop. Near-zero setup. Lead with this one. |

Lead with statement import.
It converts faster because there is nothing to configure.

### 5.3 More than 20 transactions, never opened Explore

Segment `depth_habitual_no_explore` (tier 6).

This is your **highest-value audience in the whole document**.
They have proven the habit and are paying full manual cost for it.
They are also the most likely to churn from friction rather than disinterest.

Remember constraint 2.3: the filter is `sd_tx_count_bucket = 21_plus`, not a numeric comparison.
And you cannot say "you've logged 23 expenses" in the copy, because only the bucket is tagged.

### 5.4 Building any other permutation

Compose from three slots.

```
[ reachability ]  AND  [ 1-3 state tags ]  AND  [ one session filter ]
```

- Reachability is always `sd_notif_status = authorized`.
- State tags are any `sd_*` from the catalog.
- The session filter is `last_session < 336` for education, or `> 336` for winback.

**Rules of thumb:**

- Three state filters is the practical ceiling.
  Four means you are describing a person, not an audience, and the segment will have two people in it.
- Always pair a "never used X" filter with a "has used something" filter.
  Otherwise you catch empty installs.
- Always add the session filter.
  Without it, every education segment quietly includes churned users.

---

## 6. Copy library

Rules that apply to everything below.

- **Title**: aim for 35 characters.
  iOS truncates the banner around there.
- **Subtitle**: optional, and iOS shows it below the title in smaller type.
  Use it for the qualifier so the title can stay punchy.
- **Body**: under 110 characters for the collapsed banner.
- **One verb, one destination.**
  Every push names a single action and lands on the screen that performs it.
- **Never open with what they failed to do.**
  "You haven't tried voice yet" is a scold.
  "Say it instead of typing it" is an offer.
- **Never promise a screen the router cannot reach.**
  See constraint 2.5.

Personalization uses OneSignal Liquid against tag names, with a default for safety:

```
{{ sd_quota_voice | default: '0' }}
```

### 6.1 Tier 2: onboarding stalled

Path: none (opens the app; onboarding shows itself).
Campaign: `inactive_onboarding_v1`.
Send once, then never again.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | Two minutes to finish setup | | You stopped partway. Pick up where you left off and log your first expense. |
| B | Your ledger is waiting | | Setup takes about a minute. Everything stays on your phone. |

### 6.2 Tier 3: never activated

Path: none until a create-sheet route exists.
Campaign: `activation_first_row_v1`.
Max two sends ever, roughly day 3 and day 7.

The goal is **one row**, not a feature.
Make the ask embarrassingly small.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | Log one thing. That's it. | | Your last coffee, your last cab. One row is enough to see how this works. |
| B | Empty ledger, empty insight | Takes about 10 seconds | Add a single expense and Spendrift starts doing the rest. |
| C | Start with today | | What did you spend since this morning? Type it once and you're set up. |

Do not mention voice, SMS, receipts, or Pro in tier 3.
Every extra option is a reason to postpone.

### 6.3 Tier 4: dormant

Path: none.
Campaign: `inactive_churn_d14_v1` and `inactive_dormant_d30_v1`.

Catch-up, never a feature tour.

| # | Segment | Title | Subtitle | Body |
| --- | --- | --- | --- | --- |
| A | dormant 14d | Your ledger is still here | | Two weeks of spending is easier to reconstruct now than next month. |
| B | dormant 14d | Pick up where you left off | | Nothing was lost. Everything is still on your phone, waiting. |
| C | dormant 30d | One last nudge | | If tracking spending is still on your list, Spendrift is a minute away. |

Message C is the final send to that install.
Past 60 days, stop entirely.

### 6.4 Tier 5: manual only, never voice

Path: `/explore`.
Campaign: `try_voice_v1`.
Segment: `edu_manual_only_no_voice`.

The pitch is time, not novelty.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | Stop typing every expense | | Tap the mic and say "280, lunch". Spendrift fills in the rest. |
| B | Say it instead | Works from the lock screen too | "Groceries, 1,240" is one sentence. Typing it is four taps. |
| C | You have {{ sd_quota_voice \| default: '10' }} voice notes left | Free this month | Speak an expense once and you will not go back to typing. |

Variant C only works once you have confirmed the tag renders.
Send it to yourself first.

### 6.5 Tier 5: voice user, never imported bank data

Path: `/explore`.
Campaign: `try_statement_v1` and `try_sms_v1`.

Lead with statement import.
Zero configuration beats a higher ceiling.

| # | Feature | Title | Subtitle | Body |
| --- | --- | --- | --- | --- |
| A | Statement | One PDF, a whole month | | Drop last month's bank statement in and AI logs every transaction at once. |
| B | Statement | Catch up in one step | Statement import | You have been logging one at a time. This does the entire month. |
| C | SMS | Your bank already texted you | | Spendrift can read those messages and log them while the app is closed. |
| D | SMS | Let your bank do the typing | Set up once | Every bank SMS becomes a ledger row, automatically, with the app shut. |

### 6.6 Tier 5: never opened Explore

Path: `/explore`.
Campaign: `explore_never_seen_v1`.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | There's a faster way to log | | Explore has shortcuts that add expenses without opening Spendrift. |
| B | Three shortcuts you haven't seen | | Speak, type, or let bank SMS log itself. All set up in Explore. |

### 6.7 Tier 5: saw Explore, added nothing

Path: `/explore`.
Campaign: `explore_saw_not_added_v1`.

They already evaluated and did not act.
Reduce the perceived cost, do not re-pitch the feature.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | The shortcut takes one tap | | You looked at Explore. Adding the shortcut is genuinely one tap from there. |
| B | Still worth 30 seconds | Add shortcut | Set it once and logging an expense never needs the app again. |

### 6.8 Tier 5: voice in-app, no Siri shortcut

Path: `/explore`.
Campaign: `voice_to_siri_v1`.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | You already talk to Spendrift | | Add the shortcut and do it from the lock screen, without opening the app. |
| B | Skip the app entirely | Siri shortcut | "Hey Siri, log an expense." Same voice capture, no unlocking. |

### 6.9 Tier 6: habitual, never opened Explore

Path: `/explore`.
Campaign: `depth_habitual_explore_v1`.

Lead with earned respect.
This person has done real work by hand.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | You've built the habit | | Now make it automatic. Explore has shortcuts that log without opening the app. |
| B | You're doing this the hard way | | Every expense you logged by hand could have been one sentence to Siri. |
| C | Power user, manual tools | Worth 30 seconds | Your logging habit is solid. Your setup is still on default. |

Variant B is sharper and will out-convert A, but only for people with a real streak.
Never send B below `21_plus`.

### 6.10 Tier 6: nearly out of credits

Path: `/explore` today.
**Hold this campaign until `/pro` exists.**
Campaign: `quota_voice_low_v1`.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | {{ sd_quota_voice \| default: '0' }} voice notes left | | Your free credits refill on the 1st. Pro removes the limit entirely. |
| B | Running low on voice | Free tier | You are using this enough to feel the ceiling. That is what Pro is for. |

### 6.11 Tier 6: repeatedly hitting the wall

Path: `/pro` when it exists.
Campaign: `quota_wall_pro_v1`.
Cap at one per 14 days, not 7.
This audience is already frustrated.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | You keep hitting the limit | | That is the free tier working as intended. Pro just removes it. |
| B | Third time this month | | Unlimited voice, receipts, and statements. No monthly counter. |

### 6.12 Tier 1: transactional

Outside the weekly cap.
These are service messages, not marketing.

| # | Kind | Title | Subtitle | Body |
| --- | --- | --- | --- | --- |
| A | Trial ending | Your trial ends in 2 days | | After that, voice drops to 10 a month and statements to 1. |
| B | Trial ending | Two days of Pro left | | Nothing is lost when it ends. The limits just come back. |
| C | Quota refill | Your free AI credits are back | | Voice notes, receipts, and a statement parse just refilled for the month. |

The quota refill already ships as a **local** notification.
Do not duplicate it remotely.

### 6.13 Tier 6: lapsed winback

Path: `/pro` when it exists.
Campaign: `pro_winback_v1`.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | Your ledger is still complete | | Everything you logged is here. Pro features are the only thing paused. |
| B | Come back to unlimited | | You used the AI features enough to know what they save you. |

### 6.14 Tier 7: feedback

Path: `/feedback`.
Campaign: `feedback_nudge_v1`.
Send once ever.

| # | Title | Subtitle | Body |
| --- | --- | --- | --- |
| A | What's missing? | Two minutes | You've used Spendrift for a week. Tell us the one thing that annoys you. |
| B | You've earned an opinion | | A week of real use is exactly the feedback that changes what we build. |

Your current live copy is `Feedback needed` / `Your feedback helps us improve more than anything else.`
That is about you, not about them.
Both variants above give the user a reason to tap.

---

## 7. Operating the program

### 7.1 Frequency, timing, caps

- Enable **app-level frequency capping** in OneSignal at 1 message per 7 days.
- Mark trial-ending and quota-refill as exempt.
- Send education in the **evening, local time**, using `delayed_option: "timezone"` with `delivery_time_of_day: "19:30"`.
  Spending is a thing people reflect on after the day, not at 9am.
- Send transactional immediately.
- Never send two campaigns to overlapping segments in the same week.
  The ladder plus `excluded_segments` is how you guarantee that.

### 7.2 Templates versus inline copy

You currently have **zero templates**, and your last few sends rewrote the same feedback copy by hand each time.

Create one template per campaign family:

- `tpl_activation`
- `tpl_education_capture`
- `tpl_education_explore`
- `tpl_quota`
- `tpl_winback`
- `tpl_feedback`

Put the Liquid personalization in the template, and pass the variable parts via `custom_data`.
This is what stops copy drifting between sends and makes A/B comparison meaningful.

### 7.3 What you cannot write yet, and what to add

| Copy you want | Blocked by | Fix |
| --- | --- | --- |
| "You've logged 23 expenses" | Only the bucket is tagged | Add `sd_tx_count` as a raw int alongside the bucket |
| "You haven't given feedback" | No tag | Add `sd_feedback_submitted` |
| "Your charts are ready" | No `/analytics` route | Add `AppRoute.analytics` |
| Any Pro pitch landing on the paywall | No `/pro` route | Add `AppRoute.pro` |
| "Try voice" excluding denied mics | Mic permission is not tagged | Add `sd_mic_status`, or exclude via a PostHog cohort on `voice_capture_failed` reason `mic_permission_denied` |
| Anything about the widget | No reliable install signal | Proxy via `widget_tapped` plus a timeline-refresh flag |

The two routes are the highest leverage items here.
They unblock tiers 6 entirely, which is where revenue lives.

### 7.4 Journeys versus manual sends

Use a **Journey** for the day-N drip, because the timing is relative to each user's own install date and you cannot express that with a static segment (constraint 2.1).

Use **manual or scheduled sends** for everything state-based, where "who qualifies today" is a segment query.

Suggested Journey, entry on subscription creation:

| Day | Branch condition | Campaign |
| --- | --- | --- |
| 0 | none | No push. Permission is requested in Settings by design. |
| 3 | `sd_has_transaction = false` | `activation_first_row_v1` A |
| 7 | `sd_has_transaction = false` | `activation_first_row_v1` C, then exit |
| 7 | `sd_has_transaction = true` AND `sd_seen_explore = false` | `explore_never_seen_v1` |
| 12 | `sd_used_voice = false` | `try_voice_v1` |
| 18 | `sd_used_pdf = false` AND `sd_used_sms = false` | `try_statement_v1` |
| 25 | `sd_quota_hits_30d > 0` | `quota_voice_low_v1` |
| 30 | habitual and active | `feedback_nudge_v1` |

Every step skips if the success tag is already true.

### 7.5 Measurement

One funnel, joined on the `campaign` label:

```
OneSignal sent
  -> OneSignal confirmed delivery      (needs the service extension, which ships)
    -> PostHog notification_opened     kind=push, campaign=...
      -> PostHog app_opened            within 1 hour
        -> the campaign's success event within 24 hours
```

Success event per family:

| Campaign family | Success event |
| --- | --- |
| Activation | `first_transaction_created` |
| Voice education | `transaction_created` method=`voice` |
| Statement / SMS education | `transaction_created` method=`pdf` / `sms` |
| Explore | `explore_viewed` then `explore_shortcut_tapped` (both need adding) |
| Quota / winback | `paywall_viewed` then `purchase_started` |
| Feedback | `feedback_submitted` |

Read it this way:

- Delivery is fine but opens are flat: **the copy or the audience is wrong**.
- Opens are fine but the success event is flat: **the landing path is wrong**.

The second case is the one constraint 2.5 causes, and it will look like a copy problem until you check the route.

---

## 8. Problems in the current setup

Found by reading the live OneSignal app against the code.

1. **`Voice Quota Less Than 18` is an accidental all-users segment.**
   Free voice quota is 10, so every untouched free user matches `< 18`.
   Replace with `sd_quota_voice < 3` AND `sd_used_voice = true`.
2. **Every campaign so far targeted `Total Subscriptions`.**
   Including the feedback nudge, sent repeatedly to everyone.
   Nothing used the ladder.
3. **Zero templates exist**, so copy is retyped per send and cannot be compared across sends.
4. **`Low on voice reminder` has not delivered successfully.**
   Two sends, zero successful, one failed.
   Debug it before scheduling anything on that segment.
5. **The existing recipes in `ONESIGNAL_CAMPAIGNS.md` use `sd_days_since_install` for inactivity.**
   Per constraint 2.1, those cannot match churned users.
   They need the session-filter rewrite in section 4.
6. **The install base is 3 subscribers.**
   Do not build 14 segments for 3 people.
   See the order below.

---

## 9. What to do, in order

1. Fix the `Voice Quota Less Than 18` segment, or delete it.
2. Enable app-level frequency capping at 1 per 7 days.
3. Create three segments only: `ladder_not_activated`, `edu_manual_only_no_voice`, `depth_habitual_no_explore`.
   These cover the three audiences you asked about and are the ones with real upside.
4. Create `tpl_activation` and `tpl_education_capture` so copy stops drifting.
5. Add `explore_viewed` and `explore_shortcut_tapped` to PostHog.
   Without them, every Explore campaign is unmeasurable.
6. Add `AppRoute.pro` and `AppRoute.analytics`, and extend `APP_PUSH_PATHS`.
   The app must accept a path before the backend allowlists it.
7. Add `sd_tx_count` as a raw int so depth copy can use real numbers.
8. Run one campaign end to end and watch the full funnel in section 7.5.
   `depth_habitual_no_explore` is the best first choice: small, high intent, and the success event is easy to see.
9. Only then build the Journey in section 7.4.

Do not start with the Journey.
A drip built on unmeasured campaigns compounds the mistakes instead of the results.

---

## 10. Source map

| Concern | Code |
| --- | --- |
| Tag definitions and sync | `Spendrift/Services/Notifications/AudienceTags.swift` |
| Push routes | `Spendrift/Services/Navigation/AppRoute.swift` |
| Path allowlist | `spendrift-backend/src/types/pushCampaign.ts` |
| Send payload | `spendrift-backend/src/services/oneSignalClient.ts` |
| Quota arithmetic | `Spendrift/Services/Pro/AIQuotaStore.swift`, `Spendrift/Services/Pro/ProFeature.swift` |
| Event taxonomy | `Spendrift/Services/Analytics/Analytics.swift` |
| Tag contract | `Spendrift/docs/ONESIGNAL_CAMPAIGNS.md` |
| What PostHog knows | `Spendrift/docs/TRACKING_AND_AUDIENCES.md` |

OneSignal app: `Spendrift App` (`a0407bea-0783-42b6-898b-e1eaf5940643`).
PostHog project: [Spendrift-Prod](https://us.posthog.com/project/471235).

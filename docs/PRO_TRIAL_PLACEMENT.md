# Spendrift Pro — where the 7-day trial is offered, and why

**Decided:** September 6, 2026.
**Companion doc:** [`PRO_PRICING.md`](PRO_PRICING.md) covers what the subscription costs in each
region and how those numbers were derived.

## The question

Spendrift needed a paid tier: every voice parse, SMS import, statement import and
receipt scan hits a paid OpenAI proxy, and `NEXT_STEPS_STRATEGY.md` had already
flagged "every AI call costs money at $0 revenue" as the standing risk.

The original instinct was to show the trial sheet immediately on install — collect
payment details up front, start the subscription after seven days. That is the one
placement the 2026 benchmark data argues hardest against.

## What the data says about placement

Adapty's 2026 benchmark across ~16,000 apps, by paywall trigger point:

| Placement | Trial start | Trial→paid | Day-0 churn | Revenue/install |
|---|---|---|---|---|
| Immediate (app open) | 31% | 42% | 24% | $1.12 |
| After onboarding (3–5 screens) | 48% | 48% | 19% | $2.08 |
| **After first value moment** | **65%** | **56%** | **12%** | **$3.74** |
| Delayed (2+ sessions) | 38% | 61% | 8% | $2.89 |
| Feature-gated (contextual) | 42% | 59% | 10% | $3.21 |

Firing after a measurable value moment produces 2.1x the trial starts and 3.3x the
revenue per install of an immediate hard paywall. Immediate placement is last on
revenue per install of every option measured.

Three further findings shaped the design:

- **~90% of trial starts happen on Day 0.** There is no "I'll think about it and come
  back", so the offer has to land while the user is still holding the result.
- **Finance is a multi-session category.** RevenueCat's 2026 report notes 3-day trials
  underperform in finance specifically, because users need more than one sitting to
  judge the product. 7 days spans a weekend plus a work week.
- **Freemium converts at 2.1% at Day 35 against 10.7% for hard gating.** A quota that
  eventually bites is therefore doing real work; an unlimited free tier with a polite
  nag would not.

## What we shipped

The trial is offered **immediately after the first *successful* use of each AI
feature** — the user's first parsed voice note, first SMS batch, first statement, first
receipt. The sheet leads with what just happened ("That was Spendrift Pro") rather
than with a wall.

This is the 65% cell rather than the 42% feature-gate cell: the feature runs first and
the ask comes after, so the user is being asked to keep something they have already
seen work.

Below Pro sits a monthly free allowance per feature — 10 voice parses, 30 SMS
messages, 5 receipts, 1 statement — so nobody is stopped on their first day, and the
gate only appears once the habit is real. Manual tracking, accounts, categories,
charts, widgets and Shortcuts are free forever.

### Why not a wall at install

Beyond the revenue-per-install gap: Spendrift has **zero ratings on both storefronts**,
and `COMPETITIVE_LANDSCAPE.md:33` concludes that ratings, not price, are the binding
constraint on installs. 50 of 51 profiled competitors are free. A wall at install
starves the review flow the app most needs, in a category where free is the norm.

### The India constraint

Spendrift is an iOS app selling a digital subscription, so Apple requires In-App
Purchase — we never collect or see card details, which removes any Stripe, Razorpay or
RBI e-mandate work.

But Apple no longer accepts Indian credit or debit cards for recurring App Store
billing. The live rails are **UPI Autopay** and Apple Account balance, and a StoreKit
trial still needs an eligible payment method on the Apple ID. Credit cards reach under
10% of Indian adults, so a card-gated trial would have blocked trial starts rather than
filtered for intent. Purchase-failure copy names UPI Autopay explicitly instead of
showing a generic "purchase failed" — see `ProEntitlement.message(for:)`.

## Design decisions worth remembering

- **Credits are spent when the backend answers, not when a transaction is created.**
  A parse that lands in the manual-review sheet still cost money; a failed recording or
  an unreadable PDF costs the user nothing.
- **The celebration fires on the user-visible win, not on the parse.** Statement import
  pitches on save, once rows are in the list — not over the preview.
- **SMS import never shows a modal.** It drains headlessly from a Shortcuts automation,
  so a blocked drain is reported by `MessageInboxImportBannerView` on next open
  ("12 messages waiting — free limit reached"). Silently doing nothing would read as a
  bug, and a modal fired from a background drain would ambush the user later.
- **Blocked SMS messages stay queued.** Nothing is discarded; the backlog drains next
  month or the moment the user subscribes.
- **One paywall per launch, one celebration per feature ever.** At most four
  celebrations in the app's lifetime.
- **The notification opt-in wins.** It fires on `first_transaction_created`, which can
  be the same instant as a first voice win. The paywall queues behind the alert rather
  than swallowing it — and that permission is what makes the day-5 trial reminder
  possible.
- **A day-5 trial reminder is a feature, not a leak.** A pre-trial-end reminder is
  reported to improve trial retention, and it prevents the surprise-charge one-star
  reviews that an app with no rating cushion cannot absorb.

## Measuring whether the placement was right

The funnel in PostHog:

```
app_opened → first AI success → paywall_viewed → trial_started → purchase_completed
```

Benchmarks to judge against: healthy subscription apps turn 15–30% of installs into
trials and 40–65% of trials into paid. Because ~90% of trial starts happen on Day 0, a
long tail of trial starts arriving days after the first AI success means the sheet is
landing too late and should move earlier in the success flow. Watch the one-star review
rate alongside — that is the signal the gate is set too tight.

## Sources

- [Adapty — What does a high-performing paywall look like in 2026?](https://adapty.io/blog/high-performing-paywall-2026/)
- [RocketShip HQ — The Adapty 2026 benchmark finding that should change how you time your paywall](https://www.rocketshiphq.com/adapty-subscription-app-benchmark-2025-summary/)
- [RevenueCat — State of Subscription Apps 2026](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)
- [RevenueCat — The right trial length isn't 7 days](https://www.revenuecat.com/blog/growth/7-day-trial-subscription-app)
- [Google — Now pay for subscriptions via UPI on Google Play](https://blog.google/intl/en-in/products/platforms/now-pay-for-subscriptions-via-upi-on-google-play/)
- [Apple Support — About billing for Apple subscriptions and media products in India](https://support.apple.com/en-us/108110)

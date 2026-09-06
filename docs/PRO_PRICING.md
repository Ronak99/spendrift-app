# Spendrift Pro — regional pricing

**Decided:** September 6, 2026.
**Companion doc:** [`PRO_TRIAL_PLACEMENT.md`](PRO_TRIAL_PLACEMENT.md) covers *when* the trial is
offered. This one covers *what it costs*.

## The prices

| Storefront | Monthly | Yearly | Yearly shown as | Discount | Yearly ÷ monthly |
|---|---|---|---|---|---|
| **US** | $4.99 | $29.99 | $2.50/mo | 50% | 6.0x |
| **Europe (EUR)** | €5.99 | €35.99 | €3.00/mo | 50% | 6.0x |
| **India** | ₹149 | ₹999 | ₹83/mo | 44% | 6.7x |

For india, I am going with
| **India** | ₹69 | ₹499 | ₹41/mo | 59% | ?x |

All three keep the yearly plan at 6–6.7x the monthly price, inside the **5–7x band** that
converts best across the category. The usual reference point is $9.99/mo ÷ $59.99/yr — 6x,
about a 50% annual discount. Below 5x the annual stops looking like a deal; above 7x it starts
looking like a trick.

Every plan carries the same **7-day free trial**, and the paywall renders the yearly plan as a
monthly equivalent (`ProPaywallView.monthlyEquivalent`), which lifts annual plan selection by
**28–34%**.

## Deriving the US anchor

The US price is the anchor; the other two are derived from it.

**The relevant peer is not Monarch or YNAB.** Those charge $14.99/mo and $99–109/yr because
they do bank aggregation and pay Plaid for it. Spendrift deliberately does not — per
`COMPETITIVE_LANDSCAPE.md`, its demand pool is precisely "people who want the tracking without
handing over banking credentials."

The true comparables:

| App | Monthly | Yearly | Notes |
|---|---|---|---|
| MoneyCoach | $9.99 | $29.99 | Indie iOS budget app — the closest peer |
| Wallet (BudgetBakers) | €4.49 | discounted annually | Occasional lifetime tier |
| Spendee Premium | ~$1.92 effective | — | Free tier below it |
| Pocket Clear Pro (India) | ₹149 | — | Same category, Indian storefront |
| *Global median, all categories* | *$12.99* | *$38.42* | 16,000-app dataset |

$4.99/$29.99 lands just **under** the global median. That is the correct side of it for an app
with **zero ratings on both storefronts** in a category where 50 of 51 profiled competitors are
free: volume and reviews matter more than ARPU until there is social proof to convert against.

## Deriving Europe and India

Adapty's 2026 regional pricing index, with the US at 1.0:

| Region | Index | Region | Index |
|---|---|---|---|
| UK, France, Germany, Italy, Spain | **1.2x** | Canada | 0.9x |
| South Africa | 1.1x | Australia, Japan | 0.8x |
| Saudi Arabia | 1.0x | Mexico, Turkey, Indonesia | 0.7x |
| | | **India** | **0.6x** |

Median year-one LTV per paying user tells the same story: **$32** North America, **$25** Western
Europe, **$23** globally, **$14** India and Southeast Asia.

**Europe at 1.2x** is almost exactly where Apple's EUR tier opposite $4.99 already lands (€5.99,
VAT-inclusive). Europe also ran 18% year-over-year price increases in 2026, so this is not an
aggressive position.

## Where we deliberately price below the index: India

Strict 0.6x of $29.99 would be roughly ₹1,550/yr. We price at **₹999** instead. Three reasons:

1. **₹149/mo is the price point Indians already recognise for a digital subscription.**
   Pocket Clear Pro is ₹149/mo in this exact category, and Spotify, YouTube Premium and Netflix
   mobile all cluster at ₹119–149. Pricing above that makes Spendrift the expensive option in a
   market where nearly every competitor is free.
2. **₹999 clears the ₹1,000 psychological barrier.** ₹1,299 does not.
3. Adapty's own read is that India is a **high-volume, low-ARPU market needing a completely
   different strategy** from premium markets — not a discounted copy of the US one.

The index describes what apps *do* charge, much of which is badly localised USD. The evidence
that those defaults are wrong is that **locale-specific pricing experiments carry a 62.3% LTV
uplift win rate — the highest of any experiment type in the dataset.**

## Open risk: "unlimited" is unsafe at ₹999

After Apple's 15% cut (Small Business Program), ₹999/yr nets about ₹849 — roughly **$0.80 per
month per Indian annual subscriber**. Spendrift's marginal cost is a real OpenAI call every time
someone speaks, imports a statement or scans a receipt. A genuine power user can go
margin-negative, and India is simultaneously where the price is lowest and where SMS auto-import
volume is highest.

**Recommendation:** keep "unlimited" as the promise, but implement a **fair-use ceiling** well
above normal behaviour — on the order of 300 voice parses and 20 statement imports per month —
with soft messaging rather than a hard stop. `ProFeature.monthlyFreeQuota` already provides the
shape; Pro would read a second, much larger ceiling.

**This is not built yet.** Worth doing before launch rather than after the first invoice.

## Implementation status

- **India** — already carried in code: `Products.storekit` and the paywall use ₹999/₹149.
- **US and Europe** — App Store Connect only. Set **$4.99/$29.99** as the base US tier, then
  **override** the EUR storefronts to €5.99/€35.99 and India to ₹149/₹999 rather than letting
  Apple auto-convert from the US price. Pick the nearest available tier if €35.99 is not
  offered; Apple has 900 price points, but the increments widen above €10.
- Product IDs: `com.ronakpunase.Spendrift.pro.yearly`, `com.ronakpunase.Spendrift.pro.monthly`,
  both in the single subscription group "Spendrift Pro".

## Sources

- [Adapty — Which app markets are growing fastest in 2026?](https://adapty.io/blog/fastest-growing-app-markets-2026/) — regional pricing index, LTV by region
- [PPC Land — Adapty's 2026 benchmark report](https://ppc.land/95-of-app-subscription-revenue-goes-to-top-10-adaptys-2026-benchmark-report/)
- [Business of Apps — App Pricing Benchmarks 2026](https://www.businessofapps.com/data/app-pricing/) — global medians, annual/monthly ratios
- [Airbridge — Subscription App Pricing by Category: 2026 Benchmarks](https://www.airbridge.io/en/blog/subscription-app-pricing-by-category-2026-benchmark)
- [MoneyCoach pricing](https://www.xpay.sh/saas-pricing/moneycoach/) · [Spendee pricing](https://www.spendee.com/pricing) · [Wallet by BudgetBakers Premium](https://support.budgetbakers.com/hc/en-us/articles/7151349344018-Everything-about-Premium)
- [Mirava — Apple App Store Price Tiers 2026](https://www.mirava.io/blog/apple-app-store-price-tiers-how-they-work-2026)

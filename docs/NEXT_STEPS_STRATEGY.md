# Spendrift iOS — Next Steps Strategy

> **Context:** App is live on the App Store with 10+ downloads. Initial traction driven by YouTube videos:
> - v1: https://www.youtube.com/watch?v=LFwdCAq4R1E
> - v2: https://www.youtube.com/shorts/bL-Yen5zUGY
> - v3: https://www.youtube.com/shorts/IrpI1IQEy4c
>
> **Last updated:** June 15, 2026

---

## Current State

### What's working
- **YouTube is the proven growth channel** — all traction traces back to 3 videos
- **Feature set is already strong** for a v1 (~89 features documented in `FEATURES_AND_MONETIZATION.md`):
  - Manual transaction entry
  - Voice capture (OpenAI `gpt-audio-mini`)
  - PDF bank statement import (OpenAI `gpt-4o`)
  - Siri Shortcuts & widgets + Live Activities
  - Multi-account, categories (MRU ordering), themes
  - Full analytics tab (Statistics)
- **Backend proxy is in progress** — see `spendrift-backend/docs/BACKEND_ROADMAP.md`

### Critical gaps (app-side)
| Gap | Risk | Priority |
|-----|------|----------|
| **No product analytics** | Can't measure activation, retention, or feature usage | High |
| **No crash reporting** | Blind to production failures | High |
| **OpenAI key still in app bundle** (`AppSecrets.openAIAPIKey`) | Key extraction + unbounded API cost per download | **Urgent** (blocked on backend proxy) |
| **No monetization** | Every AI feature user costs money with $0 revenue | Medium (plan now, charge later) |
| **Small UX papercuts** | Friction for users videos send to the app | Medium |

---

## Recommended Priority Order



### 1. Instrument the app (~1 day of work)

**Why:** You can't steer without signal. 10 downloads is noise; 100 instrumented downloads is a roadmap.

**Recommended tools:**
- **TelemetryDeck** — privacy-first, aligns with "on-device private" brand
- **PostHog** — alternative if you want funnels/session replay
- **Sentry** — crash reporting

**Events to track (minimal set):**

| Event | Purpose |
|-------|---------|
| `onboarding_completed` | Funnel start |
| `first_transaction_created` | **Activation** (most important metric) |
| `transaction_created` (with `method`: voice / type / pdf) | Feature pull |
| `voice_capture_failed` / `pdf_import_failed` | Error rates |
| `app_opened` (with `days_since_install`) | D1 / D7 retention |
| `shortcut_used` / `widget_tapped` | Channel attribution |

**Key metrics to watch:**
- Install → first transaction (activation rate)
- D1 and D7 retention
- Voice vs type vs PDF usage split
- AI feature failure rate

---

### 3. Double down on YouTube (measured marketing)

**Why:** It's the only proven growth lever. Don't abandon it for features nobody has asked for yet.

**What to do:**
- Make more videos using existing scripts (`YOUTUBE_LAUNCH_SCRIPT.md`, `YOUTUBE_LAUNCH_SCRIPT_V2_DIRECT.md`)
- With analytics in place, tie video → installs → activation
- Learn which framing converts (voice hook vs shortcuts vs statement import)
- Link demo video from App Store listing
- Do an ASO pass: keywords, screenshots, subtitle

**Don't:** Spend on paid ads yet. Organic YouTube is working and free.

---

### 4. Fix small UX papercuts

**Why:** Quick wins that reduce friction for users your videos send.

| Issue | Source | Impact |
|-------|--------|--------|
| Home-screen quick action posts `"QuickAction"` notification with **no SwiftUI subscriber** — icon long-press "Create Transaction" likely does nothing | `FEATURES_AND_MONETIZATION.md` item 50 | Broken entry point |
| Rounding inconsistent between Transactions header (>10 txns → whole rupees) and Statistics cards (always 2 decimals) | `FEATURES_AND_MONETIZATION.md` item 80 | Visual inconsistency |
| Password-protected PDFs fail with no password UI | `FEATURES_AND_MONETIZATION.md` item 60 | Support complaint if statement import is a hook |

---

### 5. Lay monetization groundwork (don't charge yet)

**Why not now:** Too little signal. Don't build a paywall before you know what people love.

**Plan for later:**
- AI features (voice + statement import) = eventual paid/limited tier (see Tier A in `FEATURES_AND_MONETIZATION.md`)
- Backend proxy makes per-user limits enforceable — see `spendrift-backend/docs/BACKEND_ROADMAP.md`
- Once analytics show feature pull, add StoreKit + soft limits (e.g. N free voice parses/month)
- Consider: 7-day Pro trial to habituate voice + import, then gate

**Packaging options (from monetization notes):**
- Single "Spendrift Pro" subscription bundling AI voice + statement import + widgets + export + advanced charts
- Consumables: "AI statement packs" for occasional importers
- Free trial: 7 days Pro

---

## Decision Guide

| Question | Answer |
|----------|--------|
| **More features?** | **No** — feature-rich and feature-blind. Building now is guessing. |
| **Analytics?** | **Yes** — highest-leverage product work right now. |
| **Marketing (more videos)?** | **Yes** — only proven channel. Keep going, but instrument first. |
| **Prioritizing downloads?** | **No** — downloads are vanity at this stage. Prioritize **activation** (download → first transaction) and **retention** (D1/D7 return). 1,000 downloads at 2% retention < 100 downloads at 40%. |

---

## TL;DR

```
Backend proxy (urgent)  →  Analytics + crash reporting  →  More (measured) videos  →  Fix papercuts  →  Monetize what data shows people love
```

**The one sentence version:** Don't build more features — build the ability to *see* what's working, protect yourself from API cost blowups, and keep making the videos that are already driving downloads.

---

## Related Docs

- `FEATURES_AND_MONETIZATION.md` — full feature inventory + monetization brainstorm
- `YOUTUBE_LAUNCH_SCRIPT.md` — v1 launch video script
- `YOUTUBE_LAUNCH_SCRIPT_V2_DIRECT.md` — v2 direct-style script
- `spendrift-backend/docs/BACKEND_ROADMAP.md` — backend proxy + future server work
- App Store: https://apps.apple.com/us/app/spendrift/id6761763507

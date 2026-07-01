# Sentry Diagnostics Methodology: Technical Observability Parallel to PostHog

*How Spendrift separates product analytics from crash reporting and verbose diagnostics — with the same centralized-facade pattern PostHog uses.*

---

## What problem does this solve?

Spendrift already instruments **product behavior** through PostHog: activation funnels, feature usage, and low-cardinality failure rates (`voice_capture_failed`, `pdf_import_failed`). That answers *"what are users doing and how often?"*

It does **not** answer:

- Why did the app crash on launch for 3 users?
- What breadcrumbs led to a SwiftData persist failure?
- Which OpenAI upstream call timed out, with what error code?
- Did the backend throw an unhandled exception outside our `ApiError` taxonomy?

**Sentry** fills that gap. Like PostHog, all Sentry traffic goes through a **centralized facade** (`Diagnostics` on iOS, `diagnostics.ts` on the backend) so feature code never imports the SDK directly.

---

## PostHog vs Sentry: responsibility split

| Question | Tool | Example |
|----------|------|---------|
| How many users completed onboarding? | PostHog | `onboarding_completed` |
| What % of voice captures fail? | PostHog | `voice_capture_failed` with `reason` |
| What tab was the user on before a crash? | Sentry | navigation breadcrumb |
| OpenAI returned 504 — stack trace? | Sentry | backend `captureException` with `code: upstream_timeout` |
| First transaction activation rate | PostHog | `first_transaction_created` |
| ModelContainer bootstrap fell back to in-memory | Sentry | `.error` message with `stage: bootstrap` |

**Rule:** Do not mirror every `Analytics.capture` call in Sentry. PostHog counts; Sentry diagnoses.

---

## Architecture

```text
iOS Feature Code
    ├── Analytics.capture(...)  →  PostHog SDK  →  {backend}/ingest  →  PostHog Cloud
    └── Diagnostics.*(...)      →  Sentry SDK   →  {backend}/sentry  →  Sentry Cloud

Backend /v1/* routes
    └── diagnostics.ts          →  Sentry Node SDK  →  Sentry Cloud (direct)
```

Both iOS facades require a configured backend URL for first-party routing (avoids content-blocker drops on analytics/diagnostics traffic).

---

## iOS facade API (`Diagnostics.swift`)

### Bootstrap

Called from `SpendriftApp.init()` immediately after `Analytics.bootstrap()`.

Skips setup when:

- User opted out (`diagnosticsOptOut` UserDefaults)
- DSN is empty or placeholder (`https://REPLACE_ME@...`)
- Backend URL is missing (no tunnel endpoint)

### Methods

| Method | Sentry signal | When to use |
|--------|---------------|-------------|
| `breadcrumb(category:message:feature:stage:data:)` | Breadcrumb | Expected flow steps (navigation, pipeline stages) |
| `log(_:level:tags:)` | `captureMessage` | Handled anomalies, degraded paths, invariant violations |
| `capture(_:tags:)` | `captureError` | Unexpected thrown errors, infrastructure failures |

### Log levels

| Level | Use case |
|-------|----------|
| `.info` | Notable state transitions (seed completed, retry succeeded) |
| `.warning` | Handled degradation (voice failure with known reason, fallback used) |
| `.error` | Handled failure without exception (ModelContainer fallback, `.unknown` voice reason) |

Fatal crashes are captured automatically by the SDK.

---

## Tag taxonomy

Defined as constants on `Diagnostics.Tag` (parallel to `Analytics.Key`):

| Tag | Values | Notes |
|-----|--------|-------|
| `feature` | `voice`, `pdf`, `receipt`, `manual`, `cloudkit`, `seeding`, `notifications`, `app` | Which subsystem |
| `stage` | `bootstrap`, `capture`, `transcribe`, `parse`, `persist`, `upload`, `reconcile` | Pipeline step |
| `method` | `manual`, `voice`, `pdf`, `receipt` | Same as Analytics |
| `reason` | `VoiceFailureReason.analyticsValue` or API error code | Low cardinality |
| `source` | `in_app`, `imported` | Voice capture origin |
| `route` | `/v1/voice/parse-transaction`, etc. | Backend only |

Breadcrumb categories: `navigation`, `feature`, `lifecycle`, `error`.

---

## PII and scrubbing rules

**Never send to Sentry:**

- Transaction amounts, notes, merchant names
- Category/account names (PostHog catalog events only)
- OpenAI prompts, completions, or file contents
- Authorization headers or client tokens
- Raw audio, PDF, or image bytes

**Allowed:**

- Stable error codes (`upstream_timeout`, `mic_permission_denied`)
- NSError domain + numeric code
- Tab names, pipeline stage names
- Truncated upstream error snippets (max 200 chars, via backend `truncateDetails`)

Both iOS (`beforeSend`) and backend (`beforeSend`) hooks strip `Authorization` headers from request context.

---

## Dual instrumentation examples

### Voice capture failure

PostHog (rate tracking):

```swift
Analytics.capture(.voiceCaptureFailed, [
    Analytics.Key.reason: reason.analyticsValue,
    Analytics.Key.source: lastCaptureSource.rawValue,
    Analytics.Key.isRetry: isRetryAttempt
])
```

Sentry (diagnostic trail):

```swift
Diagnostics.breadcrumb(
    category: .error,
    message: "voice_capture_failed",
    feature: .voice,
    stage: .transcribe,
    data: [Diagnostics.Tag.reason: reason.analyticsValue, Diagnostics.Tag.source: lastCaptureSource.rawValue]
)
if reason == .unknown {
    Diagnostics.log("voice capture failed with unknown reason", level: .error, tags: [...])
} else {
    Diagnostics.log("voice capture failed", level: .warning, tags: [...])
}
```

### PDF import failure

PostHog fires `pdf_import_failed` with API error code. Sentry adds breadcrumbs at upload start and a warning message with the same `reason` tag — no duplicate funnel event.

---

## Opt-out

Separate from analytics (`analyticsOptOut`):

- Key: `diagnosticsOptOut` in UserDefaults
- Crash reporting and diagnostics are a different App Store privacy category than product analytics
- When opted out, `Diagnostics.bootstrap()` returns early and all capture methods no-op

---

## Debug vs production

| Setting | DEBUG | Production |
|---------|-------|------------|
| iOS SDK debug logging | on | off |
| iOS performance traces | 100% | 10% |
| iOS error capture | 100% | 100% |
| Backend traces | 100% (development) | 10% |
| Tunnel URL | `{local-backend}/sentry` | `{prod-api}/sentry` |
| dSYM upload | optional locally | required in Xcode Cloud CI |

Local dev without secrets: both `Analytics` and `Diagnostics` silently no-op.

---

## Secrets and CI checklist

### iOS

| Secret | Where |
|--------|-------|
| `SPENDRIFT_SENTRY_DSN` | `DevSecrets.xcconfig`, Xcode Cloud → `ProdSecrets.xcconfig` |
| `SENTRY_AUTH_TOKEN` | Xcode Cloud env (dSYM upload only) |

Info.plist: `SpendriftSentryDSN = $(SPENDRIFT_SENTRY_DSN)`

Tunnel derived in code: `{SpendriftBackendBaseURL}/sentry`

### Backend

| Env var | Purpose |
|---------|---------|
| `SENTRY_DSN` | Backend project's DSN (direct ingest) |
| `SENTRY_TUNNEL_DSN` | iOS project DSN — validates/forwards `/sentry` tunnel |
| `SENTRY_ENVIRONMENT` | Defaults to `NODE_ENV` |
| `SENTRY_RELEASE` | Git SHA or version string |

---

## Sentry dashboard conventions

### Issue grouping

Backend OpenAI failures fingerprint by `(feature, code)` — not raw error message text.

### Recommended alerts

- New issue in production
- Regression (issue marked resolved reappears)
- Spike in issues tagged `code:upstream_timeout`
- Spike in iOS crashes on latest release

### Release tracking

- iOS: match App Store build number / CI archive version
- Backend: `SENTRY_RELEASE` env at deploy time

---

## What this does NOT do

- Replace PostHog events or funnel metrics
- Add session replay
- Log every analytics event to Sentry
- Send product catalog names to Sentry

---

## Key files

| File | Role |
|------|------|
| `Spendrift/Services/Diagnostics/Diagnostics.swift` | iOS facade (primary spec) |
| `Spendrift/Configuration/AppSecrets.swift` | DSN + tunnel URL |
| `spendrift-backend/src/diagnostics.ts` | Backend init + facade |
| `spendrift-backend/src/routes/sentry.ts` | iOS tunnel proxy |
| `Spendrift/ci_scripts/ci_post_xcodebuild.sh` | dSYM upload |

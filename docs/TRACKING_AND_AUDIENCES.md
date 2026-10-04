# Tracking, launch data, and audience targeting

This document answers three questions from the current iOS app, backend, PostHog project **Spendrift-Prod**, and Supabase project **spendrift**:

1. What data is tracked along a user's journey.
2. What is sent to PostHog and Supabase when the app launches, including iOS version, notification permission, and related census fields.
3. Which PostHog events exist today, and how Spendrift should track behavior across PostHog and OneSignal so campaigns can target people by what they have **not** done.

It also proposes the next tracking layer for unexplored features and for installs that download the app and then go quiet.

This is an inventory of **what ships in code today**, plus a recommended design.
It is not an implementation.

Live PostHog counts below are a 30-day snapshot taken on 14 September 2026.
They describe production and TestFlight traffic, not Debug or Simulator sessions.

---

## How to read this

Spendrift has no accounts and never calls PostHog `identify()`.
One install is one `device_id`.
That UUID is the join key across PostHog, OneSignal, Sentry, and Supabase.

The three stores have different jobs:

| System | Job | Good at | Not good at |
| --- | --- | --- | --- |
| **PostHog** | Behavioral history | Funnels, retention, "never did X", "did X 3 times this week" | Sending a push at 9am to a named segment |
| **Supabase** | Device census | Last launch, iOS version, app version, notification permission, PostHog id | Product events, campaign delivery |
| **OneSignal** | Delivery | Sent / delivered / clicked, tags, segments, scheduled campaigns | Being the source of truth for "has this person used voice" |

The rule that should stay true:

- PostHog records **what happened**.
- OneSignal stores a **small, current snapshot** of traits used for targeting.
- Supabase stores **durable install metadata** and is the join table between PostHog `distinct_id` and OneSignal `external_id`.

---

## 1. Identity

### `device_id`

Created on first access in `DeviceIdentity.swift`.
Stored in the Keychain (`com.ronakpunase.Spendrift.identity` / `device_id`).
Survives reinstall.
Independent of analytics opt-out and diagnostics opt-out.

Used as:

- OneSignal `external_id` via `OneSignal.login(DeviceIdentity.current)`
- Sentry user id
- Supabase `devices.device_id`
- Supabase `device_notifications.device_id`
- Supabase `feedback.device_id`

PostHog event super property and the only PostHog person property.
`Analytics.bootstrap()` registers it on events and, unless analytics is opted out, calls `identify` with this id.

### PostHog distinct id

`personProfiles` is `.identifiedOnly`.
`identify(DeviceIdentity.current)` runs at the start of each release launch that is not opted out, and again if the user opts back in.
After that call, `getDistinctId()` is the Keychain device id, and the person has a single property, `device_id`.
A reinstall generates a new anonymous PostHog id, then `identify` aliases it to the surviving Keychain id.
The working join is:

```
PostHog distinct_id
  -> public.devices.posthog_id
    -> public.devices.device_id
      -> OneSignal external_id
```

`devices.posthog_id` is written on first successful launch insert.
If that insert raced ahead of PostHog setup and stored `null`, a later launch patches it once.

### OneSignal subscription id

OneSignal's own push-subscription UUID.
Copied into `device_notifications.onesignal_subscription_id` when permission state is synced.
Useful for debugging delivery.
Targeting should keep using `external_id` (`device_id`), not the subscription id.

---

## 2. What happens at launch

Process start in `SpendriftApp.init`, then `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, then `ContentView.onAppear`.

```
SpendriftApp.init
  1. DeviceIdentity.current
  2. Analytics.bootstrap()          -> PostHog SDK (App Store / TestFlight only)
  3. Diagnostics.bootstrap()        -> Sentry (non-Debug only)
  4. DeviceLaunchLogger.record()    -> POST /v1/devices/launch -> public.devices

AppDelegate.didFinishLaunching
  5. PushNotifications.bootstrap()  -> OneSignal.initialize + login
                                    -> POST /v1/notifications/state -> public.device_notifications

ContentView.onAppear / scenePhase .active
  6. Analytics.capture(app_opened)
  7. PushNotifications.handleForeground() re-syncs notification state
```

Debug, Simulator, and Xcode/Ad Hoc builds **do not** initialize PostHog.
`DeviceLaunchLogger` still runs on those builds (except UI tests), so local launches can still write to Supabase.
OneSignal currently initializes whenever `SpendriftOneSignalAppID` is present.
It does not mirror the PostHog App Store / TestFlight gate.

UI tests (`-UITesting`) skip launch logging and notification sync.

### 2.1 PostHog at launch

SDK config:

- Host is the first-party proxy: `{backendBaseURL}/ingest`
- `captureApplicationLifecycleEvents = true`
- `captureScreenViews = false` (we send our own `screen_viewed`)
- Session replay on, screenshot mode, text inputs not masked
- Super property intended: `device_id` (not observed in production events)

Autocaptured lifecycle events (seen live):

| Event | What it means | Extra properties |
| --- | --- | --- |
| `Application Installed` | First open of this install | `version`, `build` |
| `Application Updated` | App version changed | `version`, `build` |
| `Application Opened` | Process came to foreground | `from_background`, `version`, `build` |
| `Application Backgrounded` | Process left foreground | SDK defaults |

Custom event on appear and on every return to `.active`:

| Event | Properties we set | Notes |
| --- | --- | --- |
| `app_opened` | `days_since_install`, `source`, plus `kind` and `notification_id` / `campaign` when notification-sourced | Fires twice on a cold start: `onAppear` and `scenePhase == .active`. Treat unique users / unique days, not raw count, when measuring opens. |

`source` is `notification` or `direct`. A tap recorded by either notification handler
is held for 10 seconds (and dropped on backgrounding), so both halves of a cold
start's double fire carry the same attribution.

It is best effort: iOS does not order the tap callback against the first view
appearing, so a cold start launched from a notification can still report
`source=direct`. **Count notification-driven opens with `notification_opened`, not
with `app_opened` where `source=notification`.** The property is for splitting a
session's downstream behaviour, not for sizing the funnel.

Every PostHog event, custom or autocaptured, also receives SDK and GeoIP fields from the ingest proxy.

SDK / device fields (always present on events):

- `$os`, `$os_name`, `$os_version` (this is the user's iOS version in PostHog)
- `$app_name`, `$app_namespace`, `$app_version`, `$app_build`
- `$device_manufacturer`, `$device_model`, `$device_name`, `$device_type`
- `$screen_width`, `$screen_height`
- `$locale`
- `$network_wifi`, `$network_cellular`
- `$is_emulator`, `$is_sideloaded`, `$is_testflight`
- `$is_ios_running_on_mac`, `$is_mac_catalyst_app`
- `$lib`, `$lib_version`

GeoIP fields (derived from the device's public IP at ingest, not sent by the app):

- `$geoip_country_code`, `$geoip_country_name`
- `$geoip_city_name`, `$geoip_postal_code`
- `$geoip_subdivision_1_code`, `$geoip_subdivision_1_name`
- `$geoip_continent_code`, `$geoip_continent_name`
- `$geoip_time_zone`
- `$geoip_latitude`, `$geoip_longitude`, `$geoip_accuracy_radius`

PostHog is the place that already has iOS version, app version, device model, locale, TestFlight vs App Store, and approximate geography.
Supabase duplicates a smaller, queryable census of the same facts.

`days_since_install` is a local `UserDefaults` stamp (`analyticsInstallDate`), not an App Store purchase date.
Reinstall without Keychain wipe still keeps `device_id`, but the install-date stamp resets if `UserDefaults` was cleared.

### 2.2 Supabase `public.devices` at launch

`POST /v1/devices/launch` from `DeviceLaunchLogger`.

Body:

```json
{
  "device_id": "uuid",
  "posthog_id": "anonymous-distinct-id or omitted",
  "device": "iPhone17,1",
  "ios_version": "18.5",
  "app_version": "1.4.1 (2)"
}
```

| Column | First launch | Later launches |
| --- | --- | --- |
| `device_id` | Inserted | Unchanged (primary key) |
| `install_time` | `now()` | Unchanged |
| `launch_time` | `now()` | Updated to `now()` |
| `posthog_id` | Stored if PostHog was up | Patched only if currently `null` |
| `device` | Hardware machine id (`uname`), never the user-assigned name | **Not updated** |
| `ios_version` | `UIDevice.current.systemVersion` | **Not updated** |
| `app_version` | `"CFBundleShortVersionString (CFBundleVersion)"` | **Not updated** |

That last point is a real gap.
If a user updates iOS or Spendrift after first insert, `devices.ios_version` and `devices.app_version` stay stale.
PostHog `$os_version` / `$app_version` on later events stay current.
Fix: PATCH `device`, `ios_version`, and `app_version` on every launch, not only `launch_time`.

Current table size on 14 September 2026: **2 rows**.
Launch logging is new.
Do not treat `devices` as a complete install census yet.
PostHog `Application Installed` (27 devices in 30 days) is the better historical install count until this table fills.

Ledger tables (`users`, `accounts`, `categories`, `transactions`) exist and are empty.
They are not part of the current tracking path.

### 2.3 Supabase `public.device_notifications` at launch and foreground

`POST /v1/notifications/state` from `PushNotifications.syncState()`.

Runs at OneSignal bootstrap, on every scene foreground, and after the Settings permission grant.

Body:

```json
{
  "device_id": "uuid",
  "app_version": "1.4.1 (2)",
  "permission_status": "authorized",
  "onesignal_subscription_id": "optional",
  "reward_granted": true
}
```

`permission_status` is one of:

- `not_determined`
- `denied`
- `authorized`
- `provisional`
- `ephemeral`

| Column | Meaning |
| --- | --- |
| `device_id` | Same Keychain UUID |
| `permission_status` | Current `UNAuthorizationStatus` |
| `permission_granted_at` | Set to `now()` whenever status is granted. Overwritten on every granted sync, so it is "last seen granted", not "first granted". |
| `onesignal_subscription_id` | OneSignal push subscription id, or `null` if SDK did not set up |
| `reward_granted` | Always `true` on sync. Free credits start on install and are not tied to notification permission. |
| `reward_granted_at` | Same overwrite behavior as `permission_granted_at` |
| `app_version` | Updated on every sync |
| `created_at` / `updated_at` | Row timestamps |

This is the table that answers "how many installs currently have notifications on".

Current table size on 14 September 2026: **1 row**.
Same caveat as `devices`: too new to be a complete census.

Notification permission is **not** written to PostHog as a standing property.
PostHog only sees it if the user goes through `NotificationManager.requestAuthorization()`, which fires `notification_permission_requested` and `notification_permission_granted`.
Those two events have not appeared in the last 30 days of Spendrift-Prod.
Most users have never been prompted, or were prompted before this taxonomy shipped.

### 2.4 OneSignal at launch

- `OneSignal.initialize(appID, withLaunchOptions:)`
- `OneSignal.login(DeviceIdentity.current)` so `external_id = device_id`
- Click listener attached
- Permission is **not** requested at launch
- No Data Tags are written
- No language, timezone, or custom user attributes beyond what the SDK collects itself

Campaign API today (`POST /v1/admin/push/campaign`) can only target:

- `{ "kind": "all" }` -> OneSignal segment `Subscribed Users`
- `{ "kind": "devices", "device_ids": [...] }` -> `include_aliases.external_id`

There is no tag, cohort, or "users who never opened Explore" audience on the backend yet.

Payload on every campaign:

```json
{
  "path": "/feedback" | "/explore",
  "campaign": "snake_case_label"
}
```

App routes only `/feedback` and `/explore`.
Unknown paths are ignored and still logged as `notification_opened` with `path` as received (or `"unknown"`).

### 2.5 Sentry at launch (not PostHog, not Supabase)

Non-Debug only, tunneled through `{backendBaseURL}/ingest`.

- User id = `device_id`
- Release name = `"version (build)"`
- Environment = `production`
- Traces sample rate = `0.1`
- Breadcrumbs for tab changes and feature failures
- No product-event mirroring

Sentry is for crashes and infrastructure errors.
Do not use it for audience targeting.

### 2.6 What is **not** sent at launch

These live only on-device until a later event happens, and some never leave the device at all:

- Pro vs free vs trial (`ProEntitlement`)
- Remaining AI credits (`AIQuotaStore`)
- Whether onboarding is complete (`spendriftOnboardingVersion`)
- Whether Explore was opened
- Transaction count
- Daily reminder enabled / time
- Analytics opt-out (`analyticsOptOut`)
- Widget install state
- Microphone / photo / speech permission
- Learning progress (feature does not exist yet)

Quota and entitlement are the most important missing launch traits for the campaigns you described.

---

## 3. Journey: what we track today

This is the product path as instrumented, not as designed on paper.

### 3.1 Install and first open

1. `Application Installed` (PostHog autocapture).
2. `devices` row inserted (Supabase), if launch logging is already in that build.
3. `device_notifications` row upserted with current permission, almost always `not_determined` on a fresh install.
4. `app_opened` with `days_since_install = 0`.
5. Mandatory App Store update sheet, if any, before anything else.
6. Onboarding (version `3`) if `spendriftOnboardingVersion` is lower, presented full screen.

Onboarding is three pages: Welcome, Voice, Pro.
The Voice page records the user, runs the real parse pipeline, and writes the result to the ledger stamped with the capture time.

Logged:

- `onboarding_step_viewed` with `step: welcome | voice | pro`
- `onboarding_completed` with `version: 3`

The voice demo itself is covered by the existing voice events: a failed parse still fires `voice_capture_failed`, and the backend call still spends a `voice` credit through `ProGate.recordUsage`.
There is no skip event.
Live (against the retired version `2` carousel): **21** `onboarding_completed` vs **27** `Application Installed` in 30 days.
Some installs never finish onboarding, or were already past this version.

Default account and categories are seeded when onboarding starts.
That seed is not an analytics event.

### 3.2 First session inside the app

Tabs: Transactions (0), Accounts (1), Categories (2), Settings (3), plus a Speak tab-bar CTA that does not change the selected tab.

`screen_viewed` fires **only when `selectedTab` changes**.
The first screen (Transactions) is not recorded as `screen_viewed` on a cold start.
Known `tab` values: `transactions`, `accounts`, `categories`, `settings`.

The in-tab Analytics dashboard (`TransactionAnalyticsContent`) is a toggle on the Transactions screen.
Opening it does **not** fire `screen_viewed` or any other event.
"Has this person ever seen charts" is currently unanswerable.

### 3.3 First transaction (activation)

`transaction_created` with:

- `method`: `manual` | `voice` | `pdf` | `receipt` | `sms`
- `type`: `expense` | `income` | `mixed` (batch imports)
- `count`: row count for batch imports, else `1`
- `is_retry`: `true` only for a voice retry that later succeeded

The very first transaction on that install also fires one-shot `first_transaction_created` with `method` only.
That flag lives in `UserDefaults` (`didFireFirstTransactionCreated`).

Live in 30 days:

- `transaction_created`: 433 events, 19 devices
- `first_transaction_created`: 12 devices
- methods actually seen: `manual`, `voice`, `sms`
- `pdf` and `receipt` methods are in code and have not appeared in this window

The silent typed shortcut (`QuickAmountExpenseIntent`, `openAppWhenRun: false`) writes a ledger row and **does not** call Analytics.
A user who only logs from that shortcut can look inactive in PostHog while the on-device ledger is full.

### 3.4 Capture methods

| Path | Start event | Success | Failure |
| --- | --- | --- | --- |
| Type in app | none (goes straight to save) | `transaction_created` method=`manual` | none |
| Speak from Transactions CTAs | `shortcut_used` kind=`voice` source=`transactions_cta` | `transaction_created` method=`voice` | `voice_capture_failed` |
| Speak from tab-bar CTA | `shortcut_used` kind=`voice` source=`tab_bar_cta` | same | same |
| Siri / Shortcuts voice that opens the app | `shortcut_used` kind=`voice` (no source) | same | same |
| Shortcuts imported audio | `shortcut_used` kind=`voice_import` | same | same |
| Voice retry | `voice_capture_retried` | `transaction_created` `is_retry=true` | `voice_capture_failed` `is_retry=true` |
| Receipt from camera / library | none until success or fail | `transaction_created` method=`receipt` | `receipt_scan_failed` |
| Receipt Share Extension | `shortcut_used` kind=`receipt_share` | same | same |
| PDF statement | none until save or fail | `transaction_created` method=`pdf` type=`mixed` | `pdf_import_failed` |
| SMS inbox drain on next app open | `message_inbox_synced` | `transaction_created` method=`sms` | counted in `removed_count` / banner, not a dedicated fail event |
| Widget / deep link tap | `widget_tapped` kind=`createTransaction` / `voiceExpense` / `importStatement` | depends on the flow that follows | none for the tap itself |
| Typed shortcut, app stays closed | **nothing** | **nothing** | **nothing** |
| SMS shortcut capture, app stays closed | **nothing** until next open drain | then `message_inbox_synced` | OTP skips are local only |

Voice failure `reason` values:

- `mic_permission_denied`
- `mic_unavailable`
- `recording_too_short`
- `no_speech_detected`
- `audio_unreadable`
- `transcription_failed`
- `unknown`

Receipt failure `reason` values:

- `image_prepare_failed`
- `shared_image_unreadable`
- `pipeline_error`

PDF failure `reason` is the backend error `code` when present, otherwise a Swift type name.
That is higher cardinality than the voice taxonomy.
Worth tightening later.

`message_inbox_synced` properties:

- `count` (created rows)
- `removed_count` (rejected + skipped)
- `kept_count` currently set to `skippedCount` (the name is misleading)

Live: `shortcut_used` kinds seen are `voice` and `voice_import`.
`widget_tapped` kind seen is `createTransaction`.
`voice_capture_failed` has fired (7 events, 4 devices).
`voice_capture_retried`, `receipt_scan_failed`, and `pdf_import_failed` have not appeared in 30 days.

### 3.5 Catalog (accounts and categories)

- `account_created`: `name`, `initial_balance`
- `account_deleted`: `name`
- `category_created`: `name`, `is_default`, `source` (`manual` or `migration`)
- `category_deleted`: `name`, `is_default`, `source`

These are the only events that send names or a starting balance.
The rest of the taxonomy forbids amounts and notes.
Keep it that way for transaction events.

Editing an account or category is not logged.
Deleting a transaction is not logged.

### 3.6 Settings, Explore, feedback

Opening Settings fires `screen_viewed` tab=`settings`.

Explore (`ExploreSettingsView`) has **no events**.
There is no `explore_viewed`, no per-page event for Speak / Type / SMS, and no event when the user taps **Add shortcut**.
"Has never seen Explore" cannot be answered from PostHog today.

Feedback:

- Supabase `feedback` row: `device_id`, `app_version`, `answers` JSON, `skipped_to_notes`, `notes`, screenshot flags, `locale`, `region`
- PostHog `feedback_submitted` with `skipped_to_notes` only
- `feedback_submitted` has not appeared in the last 30 days

The survey itself asks whether the person opened Explore, which shortcuts they added, how they log, and how they feel about Pro.
That is gold for product research and a poor substitute for behavioral events, because only people who open Feedback ever answer it.

### 3.7 Pro, trial, and quota

Paywall contexts: `celebration`, `quota_exhausted`, `settings`, `winback`.
Live contexts seen: `settings`, `quota_exhausted`, `celebration`.
`winback` is in code and has not fired.

Events (all of these also get `days_since_install` via `capturePro`):

| Event | Extra properties |
| --- | --- |
| `paywall_viewed` | `context`, optional `feature`, optional `remaining` |
| `paywall_dismissed` | same, only if they left without becoming Pro |
| `purchase_started` | `context`, `plan` (`yearly` / `monthly`), optional `feature`, `remaining` |
| `trial_started` | `plan`, `context` |
| `purchase_completed` | `plan`, `context` |
| `purchase_failed` | `plan`, `context` |
| `restore_completed` | `granted` (bool), including from Pro settings |
| `pro_feature_blocked` | `feature` (`voice` / `sms` / `pdf` / `receipt`) |
| `quota_exhausted` | same `feature` (fired together with blocked) |

`feature` raw values match `transaction_created.method` on purpose.

Free monthly quotas:

- Voice: 10
- SMS: 30
- Receipt: 5
- Statement: 1

Bonus credits when notifications are turned on from Settings (once per install):

- Voice +10, receipt +5, statement +1, SMS +0

Quota remaining is only attached to paywall events.
There is no standing "voice credits left = 2" signal in PostHog or OneSignal.
`quota_exhausted` in the last 30 days is `sms` only, on 1 device.

A 7-day trial reminder is local (`ProTrialReminder`), two days before conversion, and logs `notification_scheduled` kind=`trial_ending`.
It is not a remote push.

Pro status itself is not a PostHog property and not a OneSignal tag.
After `purchase_completed` / `trial_started` you can infer "was Pro at some point".
You cannot currently query "is Pro right now" without asking the device again.

### 3.8 Notifications along the journey

Local (on-device `UNUserNotificationCenter`):

- Daily spend reminders, alternating type vs voice by weekday, default 18:39
- Monthly statement nudge (day 2)
- Monthly quota-refill for free users (day 1)
- Trial-ending reminder

Remote (OneSignal):

- Only after the user grants permission from Settings
- Campaigns carry `path` + `campaign`

PostHog events:

| Event | When | Properties |
| --- | --- | --- |
| `notification_permission_requested` | System prompt shown | none |
| `notification_permission_granted` | Prompt returned | `granted` bool |
| `notification_scheduled` | Local request accepted | `kind` (`type`, `voice`, `statement`, `quota_refill`, `trial_ending`) |
| `notification_opened` | Local tap | `kind` = URL host (`createTransaction`, `voiceExpense`, `importStatement`) |
| `notification_opened` | Push tap | `kind=push`, `path`, `campaign` |

None of `notification_permission_*` or `notification_opened` have appeared in Spendrift-Prod in 30 days.
Push is too new, and the permission prompt is rare.

OneSignal, not PostHog, owns sent / confirmed delivered / clicked for remote campaigns.
The Notification Service Extension is what makes confirmed delivery real.

---

## 4. PostHog event catalog

### 4.1 Custom events in code

| Event | In code | Seen in last 30 days | Purpose |
| --- | --- | --- | --- |
| `app_opened` | yes | 1,211 / 35 devices | Session + retention |
| `screen_viewed` | yes | 1,006 / 31 devices | Tab navigation |
| `onboarding_step_viewed` | yes | new | Drop-off inside onboarding |
| `onboarding_completed` | yes | 21 / 21 | Onboarding done |
| `transaction_created` | yes | 433 / 19 | Core capture |
| `first_transaction_created` | yes | 12 / 12 | Activation |
| `shortcut_used` | yes | 43 / 15 | Capture entry points |
| `widget_tapped` | yes | 45 / 1 | Widget / URL entry |
| `voice_capture_failed` | yes | 7 / 4 | Voice errors |
| `voice_capture_retried` | yes | no | Voice retry |
| `pdf_import_failed` | yes | no | Statement errors |
| `receipt_scan_failed` | yes | no | Receipt errors |
| `message_inbox_synced` | yes | 61 / 1 | SMS drain |
| `category_created` | yes | 22 / 9 | Catalog |
| `category_deleted` | yes | no | Catalog |
| `account_created` | yes | 9 / 3 | Catalog |
| `account_deleted` | yes | 2 / 1 | Catalog |
| `paywall_viewed` | yes | 68 / 10 | Monetization |
| `paywall_dismissed` | yes | 42 / 10 | Monetization |
| `purchase_started` | yes | 7 / 4 | Monetization |
| `trial_started` | yes | 2 / 2 | Monetization |
| `purchase_completed` | yes | 2 / 2 | Monetization |
| `purchase_failed` | yes | no | Monetization |
| `restore_completed` | yes | 5 / 5 | Monetization |
| `pro_feature_blocked` | yes | 23 / 1 | Quota wall |
| `quota_exhausted` | yes | 23 / 1 | Quota wall |
| `notification_permission_requested` | yes | no | Permission |
| `notification_permission_granted` | yes | no | Permission |
| `notification_scheduled` | yes | 5 / 2 | Local schedule |
| `notification_opened` | yes | no | Local + push tap |
| `feedback_submitted` | yes | no | Feedback |
| `backup_created` | yes | no | Backup & restore, `count` = transactions saved |
| `backup_restored` | yes | no | Backup & restore, `count` = transactions restored |

`$rageclick` has also appeared (session replay / autocapture).
Ignore `$ai_*`, `$mcp_*`, `$workflows_*`, and `$pageview` in this project.
They are PostHog platform events, not Spendrift product events, and have not been seen recently.

### 4.2 Autocapture lifecycle (do use)

Prefer `Application Installed` for new-install counts.
Prefer `app_opened` unique devices per day for activity.
`Application Opened` is a second open stream from the SDK.
Do not add `app_opened` and `Application Opened` together.

### 4.3 Privacy rules already in force

Never send on transaction events:

- Amounts
- Notes
- Account names
- Category names of the transaction

Category and account **catalog** events are the exception, so default names can be learned for future seeds.

Session replay screenshots include on-screen amounts and labels.
Password fields stay masked.
That is a separate privacy surface from the event taxonomy.

---

## 5. Gaps that block the audiences you want

These campaigns are not possible with current data, even if you sat in the OneSignal dashboard:

| Desired audience | Why it fails today |
| --- | --- |
| Never opened Explore | No `explore_viewed`. Settings tab view is not the same thing. |
| Never added a shortcut from Explore | Tapping **Add shortcut** is not logged. Typed shortcut success is not logged. |
| Learning section incomplete | Feature does not exist, and there is no completion event. |
| Constantly runs out of trial / free AI credits | `quota_exhausted` exists but is an event, not a current state. Remaining credits are not tagged. Pro/trial/free is not tagged. |
| Never seen the Analytics charts | Charts are a toggle with no event. |
| Downloaded and went inactive | Possible **in PostHog** via absence of `app_opened`. Not possible **in OneSignal** until last-active (or a tag) is synced. |
| Used only manual entry, never voice | Almost possible via `transaction_created.method`, except silent typed shortcuts are invisible. |
| Notifications on, but never used SMS import | Permission lives in Supabase. SMS usage lives in PostHog. They are not joined into a OneSignal segment. |
| Is Pro right now | StoreKit state never leaves the device. |

Also: `device_id` is missing from PostHog events, so any PostHog cohort must hop through `public.devices.posthog_id` before it can become a OneSignal send list.

---

## 6. Recommended split of responsibilities

Do **not** make OneSignal the system of record for product behavior.
Do **not** query PostHog at tap-send time for every campaign.
Do **not** start calling `identify()` with emails or Apple ids just to unlock person properties.

### PostHog keeps

- Every behavioral event
- Funnels (install -> onboarding -> first transaction -> second week)
- Retention
- "Never did X" and "did X N times"
- Experimentation later
- The downstream half of a push funnel: `notification_opened` -> `screen_viewed` / `transaction_created` / `purchase_completed`

### OneSignal keeps

- Delivery
- Confirmed delivery
- Click
- **Data Tags**: a compact, current snapshot used to build segments in the dashboard and in the campaign API
- `external_id` = `device_id`

### Supabase keeps

- `devices`: last launch, iOS, app version, PostHog id
- `device_notifications`: permission, subscription id, reward
- Optional later: `device_audiences` materialized from PostHog, if tag sync is not enough

### Join

Fix `device_id` on PostHog events first.
Until then, always join PostHog -> `devices.posthog_id` -> `device_id`.

### Two ways to send a campaign

**A. Tag segments (default for "current state")**

The app writes tags whenever state changes.
You build a OneSignal segment such as `has_seen_explore = false` AND `is_subscribed`.
You send from the OneSignal dashboard or extend the campaign API with a tag filter.
This is how "never seen Explore" and "free credits remaining = 0" should work.

**B. Event cohorts (for "has not done X in N days")**

A small backend job runs HogQL, resolves `distinct_id` to `device_id`, and calls `POST /v1/admin/push/campaign` with `audience.kind = "devices"`.
This is how "installed 7 days ago, no `first_transaction_created`" and "no `app_opened` in 14 days" should work.

Use A when the trait is a boolean or a small number on the device right now.
Use B when the trait is an absence over time.

---

## 7. OneSignal Data Tags to add

Write tags from the iOS app via `OneSignal.User.addTags`.
Use string values.
Namespace with `sd_` so Spendrift tags are obvious next to SDK tags.

Sync on:

- launch / foreground (same cadence as `device_notifications`)
- after the events in the "when to update" column

| Tag | Type | Values | When to update | Used for |
| --- | --- | --- | --- | --- |
| `sd_onboarding_done` | bool | `true` / `false` | Onboarding complete | Re-nudge people stuck on first open |
| `sd_has_transaction` | bool | `true` / `false` | First `transaction_created` | Activation campaigns |
| `sd_tx_count_bucket` | enum | `0`, `1`, `2_5`, `6_20`, `21_plus` | After each create, bucketed | Habit strength without sending raw counts you do not need |
| `sd_used_manual` | bool | `true` / `false` | First manual save | "try voice" education |
| `sd_used_voice` | bool | `true` / `false` | First voice success | Inverse: never tried voice |
| `sd_used_sms` | bool | `true` / `false` | First SMS create | SMS setup nudge |
| `sd_used_pdf` | bool | `true` / `false` | First statement save | Statement education |
| `sd_used_receipt` | bool | `true` / `false` | First receipt save | Receipt education |
| `sd_used_typed_shortcut` | bool | `true` / `false` | Quick amount intent success | Explore follow-up |
| `sd_seen_explore` | bool | `true` / `false` | Explore appear | Your Explore campaign |
| `sd_explore_shortcut_added` | bool | `true` / `false` | Tapped Add shortcut | Distinguish saw vs added |
| `sd_seen_analytics` | bool | `true` / `false` | Charts toggle on | Charts education |
| `sd_plan` | enum | `free`, `trial`, `pro`, `lapsed` | Entitlement change | Pricing and winback |
| `sd_trial_ends_on` | date | `YYYY-MM-DD` | Trial start / refresh | Trial-ending remote push |
| `sd_quota_voice` | int | remaining credits | After consume / rollover / launch | "you are almost out" |
| `sd_quota_sms` | int | remaining | same | same |
| `sd_quota_receipt` | int | remaining | same | same |
| `sd_quota_pdf` | int | remaining | same | same |
| `sd_quota_exhausted_any` | bool | `true` / `false` | Any feature remaining = 0 | Broad "hit the wall" segment |
| `sd_hit_quota_voice` | bool | `true` / `false` | Sticky once true this month; clear on rollover | "constantly runs out" needs a counter instead if you want frequency |
| `sd_quota_hits_30d` | int | 0-99 | Increment on `quota_exhausted`, decay or reset monthly | The "constantly" qualifier |
| `sd_notif_status` | enum | `not_determined` / `denied` / `authorized` / `provisional` / `ephemeral` | Same as Supabase sync | Do not target denied users with push; they will not get it anyway |
| `sd_learning_complete` | bool | `true` / `false` | Future learning section | Learning nudge |
| `sd_learning_step` | int | 0-N | Each completed lesson | Incomplete-learning segment |
| `sd_last_active_on` | date | `YYYY-MM-DD` | Foreground | Inactive audiences in OneSignal without a HogQL job |
| `sd_days_since_install` | int | 0-N | Launch | Day-3 / day-7 drips |
| `sd_app_version` | string | `1.4.1` | Launch | "please update" |
| `sd_ios_version` | string | `18.5` | Launch | Support targeting |
| `sd_locale` | string | `en_IN` | Launch | Copy language later |

Do not put PII in tags.
No notes, amounts, names, or emails.

OneSignal already knows timezone and notification permission at the subscription layer.
Still send `sd_notif_status` so Supabase, PostHog, and OneSignal agree on the same vocabulary.

`sd_last_active_on` plus `sd_has_transaction` is enough to run "downloaded, opened once, never came back" from the OneSignal dashboard.

---

## 8. PostHog events to add

Keep the existing taxonomy.
Add only events that create an audience or a funnel step that tags cannot express alone.

| Event | Properties | Why |
| --- | --- | --- |
| `explore_viewed` | `source` (`settings`, `onboarding`, `push`) | Never-seen-Explore audience |
| `explore_page_viewed` | `page` (`voice`, `typed`, `sms`) | Which Explore card they reached |
| `explore_shortcut_tapped` | `page` | Saw vs tried to add |
| `analytics_viewed` | none | Never-seen-charts |
| `learning_step_completed` | `step`, `id` | Future learning |
| `learning_completed` | `version` | Future learning |
| `shortcut_logged` | `kind` (`typed_amount`) | Silent typed shortcut success |
| `message_captured` | `outcome` (`stored`, `otp_skipped`, `duplicate`) | SMS shortcut while app is closed |
| `entitlement_changed` | `plan` (`free`, `trial`, `pro`, `lapsed`) | Current Pro state in PostHog without person profiles |
| `quota_remaining` | `feature`, `remaining` | Snapshot; fire on launch and after consume, not on a timer |
| `push_state_synced` | `permission_status` | Mirror of Supabase, so PostHog cohorts can include permission |

Also fix, do not add as new product events:

1. Register `device_id` so it actually appears on events.
   Verify with a HogQL count before calling the join problem solved.
2. Fire `screen_viewed` for the initial tab on appear, not only on change.
3. Stop double-firing `app_opened` on cold start, or add `from_background` so the two can be split.
4. PATCH `devices.ios_version`, `app_version`, and `device` on every launch.
5. Set `permission_granted_at` only the first time status becomes granted.
6. Capture `transaction_created` / `shortcut_used` from `QuickAmountExpenseIntent`.
7. Attach `source` on every `shortcut_used` (`tab_bar_cta`, `transactions_cta`, `siri`, `widget`, `share`).

Optional person-property policy: stay on `.identifiedOnly`.
Standing traits belong on OneSignal tags and on event properties.
If you later want PostHog person properties, the privacy-preserving option is `PostHogSDK.shared.identify(DeviceIdentity.current)` with the same anonymous UUID, not an email.
That is a separate decision.
Tags do not require it.

---

## 9. Audience recipes

Each recipe lists the OneSignal segment when tags exist, the PostHog definition for the cohort job, the push `path`, and the point of the copy.
Do not send these until the user is `subscribed` in OneSignal.
Denied permission cannot be fixed by a push.

### 9.1 Never seen Explore

**Goal:** People who have never opened the Explore carousel, nudged to add a shortcut.

**OneSignal (after tags):** `sd_seen_explore = false` AND `sd_onboarding_done = true` AND `sd_days_since_install >= 2`

**PostHog (until tags exist):** devices with `onboarding_completed` and no `explore_viewed` (once that event exists).
Today this cohort **cannot be built**.

**Path:** `/explore`
**Campaign:** `explore_never_seen_v1`

Suggested copy direction:

- Title: Your Shortcuts are unused
- Body: Speak, type, or import bank SMS without opening Spendrift. Three taps in Explore.

Exclude people with `sd_used_typed_shortcut = true` or `sd_used_sms = true`.
They already found a capture path.

### 9.2 Saw Explore, added nothing

**OneSignal:** `sd_seen_explore = true` AND `sd_explore_shortcut_added = false` AND none of `sd_used_voice` / `sd_used_sms` / `sd_used_typed_shortcut`

**Path:** `/explore`
**Campaign:** `explore_saw_not_added_v1`

### 9.3 Free or trial user constantly out of credits

**Goal:** Nudge only people who keep hitting the wall, not anyone who used one voice note.

**OneSignal:** `sd_plan` in `free`, `trial` AND `sd_quota_hits_30d >= 2` AND `sd_quota_exhausted_any = true`

Tighter variant: `sd_quota_voice = 0` AND `sd_used_voice = true` AND `sd_plan != pro`

**PostHog backup:** `uniqExact` of days with `quota_exhausted` in the last 30 days >= 2, join to `device_id`, exclude anyone with `purchase_completed` whose latest `entitlement_changed.plan` is `pro`.

**Path:** keep `/explore` until a `/pro` or `/paywall` route exists.
Better: add `AppRoute.pro = "/pro"` and open the paywall from the router.
Do not reuse `/feedback` for this.

**Campaign:** `quota_wall_pro_v1`

Send at most once per week per device.
This audience is already frustrated.

### 9.4 Trial ending, still using AI

**OneSignal:** `sd_plan = trial` AND `sd_trial_ends_on` within 2 days AND `sd_has_transaction = true`

Local `ProTrialReminder` already covers this when the app is allowed to schedule local notifications.
Add a remote copy only for users who backgrounded the app and will miss the local request, or as a second channel after local is proven.

**Campaign:** `trial_ending_remote_v1`

### 9.5 Trial ended, lapsed, used AI during trial

**OneSignal:** `sd_plan = lapsed` AND (`sd_used_voice` or `sd_used_sms` or `sd_used_receipt` or `sd_used_pdf`)

**Campaign:** `pro_winback_v1`

### 9.6 Learning section incomplete (future)

**OneSignal:** `sd_learning_complete = false` AND `sd_onboarding_done = true` AND `sd_last_active_on` within 14 days

Do not nag inactive people about a lesson they will not open.
Inactive gets a different play (9.8).

**Path:** `/learn` (new route, not `/explore`)
**Campaign:** `learning_incomplete_v1`

Event pair to add with the feature:

- `learning_step_completed`
- `learning_completed`

Tag `sd_learning_step` so you can send "finish lesson 2" rather than a generic "you have learning".

### 9.7 Never seen Analytics charts

**OneSignal:** `sd_seen_analytics = false` AND `sd_has_transaction = true` AND `sd_tx_count_bucket` in `2_5`, `6_20`, `21_plus`

Do not send this to people with zero transactions.
Charts of nothing are a bad first impression.

**Path:** `/analytics` (new route that selects tab 0 and turns the charts toggle on)
**Campaign:** `analytics_never_seen_v1`

### 9.8 Downloaded and went inactive

Split into three, they need different copy.

**Opened once, no transaction, quiet 3 days**

- `sd_has_transaction = false`
- `sd_days_since_install` 3 to 7
- `sd_last_active_on` older than 2 days
- Campaign: `inactive_no_activation_d3_v1`
- Copy: log the coffee you just bought. One typed row is enough.
- Path: none, or `spendrift://createTransaction` once a push path exists for the create sheet.

**Activated, then disappeared for 14 days**

- `sd_has_transaction = true`
- `sd_last_active_on` older than 14 days
- `sd_plan != pro` optional
- Campaign: `inactive_churn_d14_v1`
- Copy: your ledger is still on the phone. Open Spendrift and catch up.

**Installed, never finished onboarding**

- `sd_onboarding_done = false`
- `sd_days_since_install >= 1`
- Campaign: `inactive_onboarding_v1`
- Path: none until an `/onboarding` route exists.
- Local onboarding already shows on next open, so this push is only a "come back" tap that opens the app.

**PostHog definition** (works today, no new events):

```
Application Installed in last 30 days
AND no app_opened in last 7 days
AND no first_transaction_created ever
```

Resolve `distinct_id` through `devices.posthog_id` and send `audience.kind = devices`.
This is the one campaign you can run before tags exist, as soon as `devices` has enough rows.

### 9.9 Capture-method education (unexplored features that already exist)

These are the highest-leverage "unexplored feature" audiences, because the features already ship.

| Audience | Tag filter | Path | Campaign | Idea |
| --- | --- | --- | --- | --- |
| Manual only, never voice | `sd_used_manual` and not `sd_used_voice` | `/explore` page voice | `try_voice_v1` | You typed 10 expenses. The mic on the tab bar does the same job. |
| Has transactions, never SMS | `sd_has_transaction` and not `sd_used_sms` | `/explore` page sms | `try_sms_v1` | Bank SMS can land in the ledger while the app is closed. |
| Has transactions, never receipt | not `sd_used_receipt` | Settings receipt row later, or `/explore` | `try_receipt_v1` | Photograph the bill instead of typing it. |
| Has transactions, never PDF | not `sd_used_pdf` | `spendrift://importStatement` once routed | `try_statement_v1` | Drop last month's PDF once and catch up. |
| Never used a widget | cannot know until a widget-install signal exists | Explore or a short "add widget" path | `try_widget_v1` | Needs a new event; see section 10. |
| Used voice in-app, never Siri shortcut | `sd_used_voice` and not `sd_explore_shortcut_added` | `/explore` | `voice_to_siri_v1` | You already speak in the app. Add the shortcut and do it from the lock screen. |

Voice education should exclude people with `voice_capture_failed` reason `mic_permission_denied` until they grant the mic.
Pushing "try voice" at a denied-mic user is wasted.

### 9.10 Feedback

You already designed `feedback_nudge_v1` on `/feedback`.
Tighten it:

- `sd_days_since_install >= 7`
- `sd_has_transaction = true`
- no `feedback_submitted` (PostHog) ever
- send once

Do not mix this audience with Explore or Pro nags in the same week.

---

## 10. Unexplored features: what else to track and send

"Unexplored" should mean **a shipped surface this install has not used**, not a brainstorm of new product.

### Surfaces that already exist and are under-instrumented

1. **Explore carousel** (highest priority).
   Events + tags in sections 7 and 8.
2. **In-tab Analytics**.
   `analytics_viewed` + `sd_seen_analytics`.
3. **Home-screen widgets**.
   WidgetKit cannot reliably tell you "widget is on the home screen".
   Proxy signals:
   - `widget_tapped` (already exists)
   - a daily widget timeline refresh writing `sd_widget_active = true` via an App Group flag the next app open copies to OneSignal
   Absence of both after 7 days is "probably no widget".
4. **Live Activity / Dynamic Island for voice**.
   Low value as a campaign.
   Skip until voice usage is common.
5. **Accounts and custom categories**.
   `account_created` / `category_created` already exist.
   A "you are still on the default Savings account" campaign is weak.
   Skip.
6. **Daily local reminders**.
   `notification_scheduled` exists.
   A remote "turn on reminders" campaign is only useful for `sd_notif_status = not_determined`.
   Once denied, only Settings can recover.
7. **Receipt scan and PDF import**.
   Instrument starts, not only success/fail.
   Add `receipt_started` and `statement_started` so you can see abandon vs never-tried.
8. **SMS automation setup**.
   Explore page 3 has setup steps.
   Add `sms_setup_viewed` when that page is selected.
   Tag `sd_sms_setup_viewed`.
   That is a better "almost there" audience than "never used SMS".

### Surfaces that do not exist yet

| Future surface | Minimum events | Minimum tags | Push path |
| --- | --- | --- | --- |
| Learning / lessons | `learning_step_completed`, `learning_completed` | `sd_learning_step`, `sd_learning_complete` | `/learn` |
| Budgets | `budget_created`, `budget_threshold_hit` | `sd_has_budget` | `/budgets` |
| Recurring transactions | `recurring_created` | `sd_has_recurring` | `/recurring` |
| Shared ledger / family | out of scope while identity is device-only |  |  |
| Export / CSV | `export_completed` | `sd_has_exported` | Settings |
| Multi-currency | skip until it ships |  |  |

When a new surface ships, add the **viewed** event, the **completed** event, the boolean tag, and an `AppRoute` on day one.
Retrofitting "never seen X" after launch is how Explore became invisible.

### Suggested drip for a new install (once tags exist)

These are local-time evening sends, once each, skipped if the success event already happened.

| Day | Condition | Campaign |
| --- | --- | --- |
| 0 | (no push) | Permission is requested in Settings, not at launch, on purpose |
| 1 | onboarding done, no transaction | `inactive_no_activation_d3` wait until day 3 unless they opened and bounced the same day |
| 3 | no `first_transaction_created` | log one expense |
| 5 | has transaction, not `sd_seen_explore` | open Explore |
| 8 | has transaction, not `sd_used_voice` | try voice |
| 12 | has transaction, not `sd_used_sms` | try SMS automation |
| 16 | `sd_tx_count_bucket` >= `2_5`, not `sd_seen_analytics` | open charts |
| 21 | hit quota at least once, not Pro | Pro from the wall they already felt |
| 30 | still free, active, never feedback | feedback |

Cap remote campaigns at **one per week per device** unless they are transactional (trial ending, quota refill).
Education pushes that arrive daily will earn a permission revoke, and `device_notifications.permission_status = denied` is expensive to reverse.

---

## 11. Inactive-user program

Inactive is not one segment.

### Definitions

Use `sd_last_active_on` once tags exist.
Until then, use PostHog `app_opened` and `devices.launch_time`.

| Name | Rule | Intent |
| --- | --- | --- |
| Never activated | Installed, no `first_transaction_created`, last open >= 3 days | Get one manual row in |
| New and quiet | Activated on day 0 or 1, then no open for 7 days | Reminder that the ledger is local and waiting |
| Habit broken | Was opening weekly, then 14 days silent | Catch-up, not a feature tour |
| Dormant | 30 days silent | One reactivation. Then stop. |
| Dead | 60 days silent, or permission denied and 30 days silent | Do not spend sends |

### What to send, and what not to send

Send:

- A single reason to open (log today, or your trial ended, or credits refilled)
- Deep link into that action

Do not send:

- Feature tours to dormant users
- Pro pitches to people who never used an AI feature
- Explore education to people who never finished onboarding
- Anything after they revoked notification permission

### Quiet hours and frequency

- OneSignal per-user frequency cap: 1 marketing push / 7 days
- Transactional (trial ending, quota refill) excluded from that cap
- Respect iOS notification settings.
  There is no in-app mute besides system Settings, by design.

### Measuring whether inactivity pushes work

Funnel, joined on `campaign`:

```
OneSignal sent
  -> OneSignal confirmed delivery
    -> PostHog notification_opened  kind=push  campaign=...
      -> app_opened within 1 hour
        -> transaction_created within 24 hours   (activation / catch-up)
```

If `notification_opened` does not rise, the copy or the audience is wrong.
If it rises and `transaction_created` does not, the landing path is wrong.
That is why every campaign needs a real `path`, not "open the app".

---

## 12. Campaign API evolution

Today:

```json
"audience": { "kind": "all" }
"audience": { "kind": "devices", "device_ids": ["..."] }
```

Add, in this order:

1. Keep `devices` for PostHog cohort jobs.
2. Add `{ "kind": "tags", "filters": [ { "key": "sd_seen_explore", "relation": "=", "value": "false" } ] }` mapped to OneSignal's tag filter payload.
3. Add an allowlist of campaign names so a typo cannot ship `explore_never_seen_v1` copy to `all`.
4. Add `{ "kind": "segment", "name": "..." }` only after segments are named and stable in the OneSignal app.

Extend `APP_PUSH_PATHS` when new destinations exist:

- `/feedback` (now)
- `/explore` (now)
- `/pro`
- `/analytics`
- `/learn`
- `/receipt`
- `/statement`

The app router must accept a path before the backend allowlists it.

---

## 13. Implementation order

Do not start with a learning-section campaign.
The instrumentation is not there, and neither is the feature.

1. **Fix the join key.**
   Make `device_id` appear on PostHog events.
   Confirm with HogQL.
2. **Keep the census fresh.**
   PATCH iOS version, app version, and hardware id on every launch.
3. **Instrument Explore, Analytics view, typed-shortcut success, entitlement, quota remaining.**
   These unlock the audiences you named.
4. **Write OneSignal tags** from a single `AudienceState.sync()` called next to `PushNotifications.syncState()`.
5. **Add `/pro` and `/analytics` routes.**
6. **Run one campaign** that already has a downstream event: Explore never-seen, or feedback.
   Watch the funnel in section 11.
7. **Add the HogQL -> device_ids job** for inactivity, which tags cannot express as well as PostHog can.
8. **Only then** attach learning, quota-wall Pro nudges, and the day-N drip.

---

## 14. Worked examples (after steps 1-4)

### Never seen Explore

OneSignal segment:

- First session: subscribed
- Tag `sd_seen_explore` is `false`
- Tag `sd_onboarding_done` is `true`
- Tag `sd_last_active_on` in the last 14 days

Send `explore_never_seen_v1` to `/explore`.
Success: `explore_viewed` then `explore_shortcut_tapped` or `shortcut_used`.

### Quota wall, Pro nudge

OneSignal segment:

- Tag `sd_plan` is `free` or `trial`
- Tag `sd_quota_hits_30d` greater than `1`
- Tag `sd_quota_exhausted_any` is `true`

Send `quota_wall_pro_v1` to `/pro`.
Success: `paywall_viewed` context `quota_exhausted` or `settings`, then `purchase_started`.

### Inactive after download

PostHog HogQL job, last 14 days of installs:

- Has `Application Installed`
- No `first_transaction_created`
- Max `app_opened` timestamp older than 3 days

Join `distinct_id` to `devices.posthog_id`.
Send those `device_id`s as `audience.kind = devices`.
Campaign `inactive_no_activation_d3_v1`.
Success: `app_opened` then `first_transaction_created` within 24 hours.

---

## 15. Source map

| Concern | Code |
| --- | --- |
| Event names and keys | `Spendrift/Services/Analytics/Analytics.swift` |
| Launch -> Supabase | `Spendrift/Services/Identity/DeviceLaunchLogger.swift`, `spendrift-backend/src/services/supabaseDevices.ts` |
| Notification state -> Supabase | `Spendrift/Services/Notifications/PushNotifications.swift`, `spendrift-backend/src/services/supabaseNotifications.ts` |
| OneSignal send | `spendrift-backend/src/services/oneSignalClient.ts` |
| Identity | `Spendrift/Services/Identity/DeviceIdentity.swift` |
| Device / app labels | `Spendrift/Utilities/AppInfo.swift` |
| Quota | `Spendrift/Services/Pro/AIQuotaStore.swift` |
| Pro features | `Spendrift/Services/Pro/ProFeature.swift` |
| Push routes | `Spendrift/Services/Navigation/AppRoute.swift` |
| Schema | `supabase/migrations/20260914140000_devices.sql`, `supabase/migrations/20260914180000_device_notifications.sql` |

PostHog project: [Spendrift-Prod](https://us.posthog.com/project/471235).
Supabase: project `spendrift` (`cknyaekvsqvrpmqkhelz`).

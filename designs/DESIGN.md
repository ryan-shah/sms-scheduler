# SMS Scheduler — Design Document

> **This document is authoritative.** If implementation deviates from it, record the deviation
> in the dated deviation log at the bottom. Task tracking lives in beads (`bd`), not here. Current
> work status lives in `designs/PHASE_X_CURRENT_STATUS.md`; completed phases produce
> `designs/PHASE_X_HANDOFF.md`. How phases are executed by sub-agents is in
> `designs/ORCHESTRATION.md`.

**Product in one line:** an Android app that sends recurring SMS reminders from the user's own
phone/SIM to any contacts or numbers, on schedules ranging from **every 5 minutes** to
**monthly**, with a full send history and no server.

## Product decisions (user-confirmed 2026-10-27)

| Decision | Choice | Consequence |
|---|---|---|
| How SMS is sent | **On-device, via the phone's SIM** (`SmsManager`) | Free, offline, no backend, no Twilio/A2P registration. Messages come from the user's own number. |
| Recipients | **Any contacts or typed numbers**, one or more per schedule | One individual SMS per recipient (never group MMS). Contact picker + E.164 normalization. |
| Platforms | **Android only** | No web/iOS targets, no GitHub Pages deploy. iOS/web cannot send SMS in the background anyway. |
| Distribution | **Sideloaded APK via GitHub Releases** (DejaPoo model) | Google Play restricts `SEND_SMS` to default-SMS-handler apps, so Play is out of scope. Sideloading also lets us declare `USE_EXACT_ALARM`. |

## Core features (user-confirmed 2026-10-27)

1. **Recurring schedules from every 5 minutes to monthly**, each with one or more recipients
   and its own message.
2. **Daily send window.** Any minute/hour-interval schedule can be limited to a daily start
   and end time. For example, "every 10 min, 8:00 AM–8:00 PM" sends 8:00, 8:10, …, 8:00 PM
   and nothing overnight. The default is the full 24 hours. Semantics are in §1.
3. **Reminder time in the message.** A per-schedule option, on by default, prefixes each SMS
   with its scheduled time: `3:45pm reminder: <message>`. Format is in §5.

## Non-goals

Receiving/reading SMS, being the default SMS app, MMS/group messages, cloud sync, multi-device,
iOS, web, Play Store listing, a backend of any kind.

## Stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter, Android target only | Matches DejaPoo; reuse its patterns, lints, CI |
| State mgmt | Riverpod 3 (+ `riverpod_generator`) | Same as DejaPoo; testable with overrides |
| Local DB | Drift (SQLite), native only | Schedules, recipients and the send log need real queries; no WASM needed |
| Routing | go_router | Same shell pattern as DejaPoo (bottom nav) |
| Background wake-ups | `android_alarm_manager_plus` (`oneShotAt`, `alarmClock: true`, `rescheduleOnReboot: true`) | Runs a Dart callback in a background isolate even when the app is killed; `setAlarmClock` is exempt from Doze throttling |
| SMS sending | **In-repo Flutter plugin `packages/sms_sender`** (Kotlin, ~150 LOC) | Must be a *plugin* (not a MainActivity MethodChannel) so it is registered in the alarm's background engine. Owning it avoids depending on unmaintained telephony packages |
| Timezones / DST | `timezone` + `flutter_timezone` | DejaPoo dp-5br lesson: `DateTime.now().timeZoneName` is not an IANA id on Android |
| Notifications | `flutter_local_notifications` | Failure alerts and "schedule finished" notices only. Sending SMS is not a notification |
| Permissions | `permission_handler` | SEND_SMS, POST_NOTIFICATIONS, battery-optimization exemption, exact-alarm status |
| Contacts | System contact-picker intent (via `flutter_contacts` or a small intent call; decided in Phase 4) | Prefer the picker intent, which needs **no** `READ_CONTACTS` permission |
| Phone numbers | `phone_numbers_parser` | E.164 normalization, validation, display formatting |

Exact versions are pinned in Phase 0 after a `flutter pub get` dry run. Drift/drift_dev are
pinned in lockstep, as in DejaPoo's `drift-flutter` skill.

## Core architecture

```
 UI (Riverpod)                Background isolate (alarm callback)
 ─────────────                ───────────────────────────────────
 ScheduleEditor ──┐           dispatchDue()  ◄── AlarmManager (one armed alarm)
 ScheduleList     │              │
 HistoryScreen    ▼              ▼
          ScheduleRepository / SendLogRepository  (Drift, same SQLite file, WAL)
                  ▲              │
                  │              ├─► RecurrenceEngine.next(rule, after)   (pure Dart)
                  │              ├─► SmsGateway.send(phone, body)         (sms_sender plugin)
                  └── Rearm ◄────┴─► AlarmScheduler.armNext(earliestDue)  (single alarm)
```

### 1. Recurrence engine (pure Dart, the heart of correctness)
`RecurrenceRule` is a sealed type, serialized as versioned JSON in the `schedules.rule_json`
column:

- `Interval(every: Duration)`, with minutes ≥ 5 and hours. **Elapsed-time semantics**: every
  30 min means 30 real minutes, including across DST changes.
- `Daily(everyNDays, timesOfDay[])`, `Weekly(everyNWeeks, weekdays{}, timesOfDay[])`,
  `Monthly(everyNMonths, dayOfMonth | nthWeekday, timeOfDay)`. **Wall-clock semantics**: 9:00
  stays 9:00 across DST. A nonexistent local time (spring-forward gap) shifts forward to the
  first valid instant. An ambiguous one (fall-back) fires once, at the first occurrence. Day 31
  in a 30-day month clamps to the month's last day.
- **Daily window** (`DailyWindow{start, end}` as local wall-clock times; on `Interval` rules
  only, because daily/weekly/monthly rules already name their send times). Defaults to none,
  meaning the full 24 hours.
  - **Re-anchored each day:** the first occurrence of each day is exactly `start`, then every
    `interval` after it. "Every 45 min, 8:00–20:00" gives 8:00, 8:45, 9:30, … every day, not
    times that drift from yesterday's last send.
  - **End is inclusive:** a send at exactly `end` is included (8:00 PM in the example above).
    Nothing is sent after `end` until the next day's `start`.
  - **Overnight windows** (`start > end`, e.g. 22:00–06:00) span midnight and belong to the
    day they start on.
  - **DST:** the window bounds are wall-clock times, and the steps inside the window are
    elapsed time. On a spring-forward day, an 8:00–20:00 window is still 8:00–20:00 local time.
  - Times outside the window are not occurrences at all, so they are never logged as `missed`.
    A phone that's off overnight produces no history noise.
- Other optional modifiers: **active weekdays** (e.g. weekdays only; this combines with the
  window), a **start** instant, and an **end** (never / on date / after N sends).

API: `DateTime? nextOccurrence(RecurrenceRule rule, {required tz.TZDateTime after})`.
`occurrencesBetween(...)` is used for previews and volume estimates. This code is exhaustively
unit-tested: DST in both directions in at least two zones, month-end clamping, Feb 29, window
edges, and end conditions. It has no Flutter imports.

### 2. Single-alarm dispatcher
- The system keeps **exactly one armed alarm**: the earliest `next_due_at` across enabled
  schedules. Every schedule mutation and every dispatch re-arms it. This is simpler and more
  robust than one alarm per schedule, with no alarm-id bookkeeping and no leaked alarms.
- `dispatchDue(now)` runs in the background isolate. For each enabled schedule with
  `next_due_at <= now`:
  1. **Claim** the occurrence atomically, in one transaction: insert `send_log` rows with
     status `pending`, keyed `(schedule_id, recipient_id, scheduled_for)` UNIQUE, and advance
     `next_due_at`. The UNIQUE key makes a double-fired alarm or a race between the UI's
     "dispatch on open" and the alarm harmless.
  2. **Missed-run policy:** if `now − scheduled_for > grace`, mark the occurrence `missed`
     and do not send. Grace is `min(interval/2, 15 min)`, or 15 min for daily and longer
     rules. The app **never burst-sends a backlog** (after the phone was off, for example).
     At most one occurrence per schedule is sent per dispatch.
  3. Send to each recipient through `SmsGateway`, then update each row to `sent`/`failed`
     with the error code and part count.
  4. Arm the next alarm.
- **Rate guard:** Android prompts the user once an app exceeds ~30 SMS in 30 minutes
  (`sms_outgoing_check_max_count`), and the prompt can't appear from the background, so those
  sends fail. The engine computes projected sends/30 min across all enabled schedules. The
  editor warns about any configuration that would exceed the budget, and the dispatcher
  refuses to exceed a hard cap (status `rate_limited`, user notified). The ADB override is
  documented in `docs/INSTALL_ANDROID.md`.
- **Kill switch:** "Pause all" disarms the alarm and disables dispatching globally.
- **Re-arm triggers:** app start (shell watches the re-arm provider, the dp-5br lesson),
  reboot (`rescheduleOnReboot`), app update, timezone/time change (a manifest receiver for
  `TIMEZONE_CHANGED`/`TIME_SET` that re-arms), and any schedule edit.

### 3. Cross-isolate consistency
The UI isolate and the alarm isolate each open their own Drift connection to the same file
(WAL mode with a busy timeout). Drift's `watch()` streams do not see the other connection's
writes. After a dispatch, the background isolate pings the UI through an
`IsolateNameServer`-registered `SendPort` (if one is alive), and the UI calls
`db.notifyUpdates(...)`. The UI also refreshes on app resume.

### 4. SMS gateway (`packages/sms_sender`)
The Kotlin plugin exposes `send(phoneE164, body, {subscriptionId?}) → SendResult{status, errorCode, parts}`:
- Uses `SmsManager.divideMessage` + `sendMultipartTextMessage` with per-part SENT
  `PendingIntent`s, awaiting all parts (30 s timeout). It returns the aggregate result.
- Delivery reports (DELIVERED intents) are out of scope for v1.
- On the Dart side, the plugin sits behind an `SmsGateway` interface with a `FakeSmsGateway`,
  so all logic is testable without a device.

### 5. Message rendering (time prefix)
The pure function `String renderMessage(Schedule s, DateTime scheduledFor)` lives in
`lib/domain/` and is the only place the outgoing text is built. The dispatcher, the editor
preview and "Send test now" all use it.
- When `includeTimePrefix` is true (the default), the output is
  `"<time> reminder: <body>"`, e.g. `3:45pm reminder: Take your meds`.
- `<time>` is the **scheduled occurrence time**, not the moment the send happened, in the
  schedule's IANA zone. It uses a 12-hour clock, lowercase am/pm, no space and no leading zero:
  `9:05am`, `12:00pm`, `12:30am`. Its format is fixed, not taken from the device locale, so
  the text is predictable. A 24-hour option is deferred.
- A late send within the grace window, and a manual "Retry now" from History, both keep the
  original scheduled time. The text says what the reminder was *for*.
- The text actually sent is stored in `SendLog.bodySnapshot`. The editor's segment counter
  measures the rendered text (prefix included, about 17 characters), so the user sees when the
  prefix pushes a message past 160 characters into a second SMS segment.
- Unit-tested cases: `12:00am`/`12:00pm` edges, single-digit hours, a DST-day occurrence
  rendered in the schedule's zone, prefix off, and a unicode body (UCS-2 segment math).

## Data model (Drift)

Follows DejaPoo's datetime rules. **Instants** (`next_due_at`, `sent_at`, `created_at`,
`updated_at`) are UTC. **Wall-clock rule fields** (times of day, anchors) live inside
`rule_json` alongside the schedule's IANA `time_zone`.

```
Schedule {
  id            uuid
  name          String
  body          String            // message text, before rendering (see §5)
  includeTimePrefix bool          // default true → "3:45pm reminder: <body>"
  ruleJson      String            // versioned RecurrenceRule JSON (incl. DailyWindow)
  timeZone      String            // IANA id captured at creation (default: device zone)
  enabled       bool
  nextDueAt     DateTime? (UTC)   // materialized; null = finished or disabled
  sendCount     int               // successful occurrences, for "end after N"
  createdAt / updatedAt / deletedAt (soft delete)
}
Recipient {
  id, scheduleId, displayName, phoneE164, contactLookupKey?, sortOrder
}
SendLog {
  id, scheduleId, recipientId, phoneE164,
  bodySnapshot                    // the rendered text actually sent (prefix included)
  scheduledFor (UTC), attemptedAt (UTC)?,
  status enum(pending|sent|failed|missed|rate_limited|skipped_paused),
  errorCode int?, parts int?
  UNIQUE(scheduleId, recipientId, scheduledFor)
}
AppSettings (key/value): pausedAll, lastDispatchAt, rateCapPer30Min, notifyOnFailure
```

The send log is pruned to the last 90 days or 10k rows, whichever is larger, and the
retention period is a Settings option.

## Permissions & manifest

`SEND_SMS` (runtime), `USE_EXACT_ALARM` (API 33+, auto-granted, valid for sideloaded apps),
`SCHEDULE_EXACT_ALARM` with `maxSdkVersion=32`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`,
`POST_NOTIFICATIONS` (runtime, 33+), and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. The
`android_alarm_manager_plus` `AlarmService`/`AlarmBroadcastReceiver`/`RebootBroadcastReceiver`
declarations are required, and the reboot receiver must be enabled. A manifest regression test
(as in DejaPoo's `test/android/android_manifest_test.dart`) guards every entry. `minSdk` 26.

## Phases

All phases run **sequentially**: one phase at a time, and within a phase one bd issue at a
time, each completed by one sub-agent (see `ORCHESTRATION.md`). Phase 1 is a deliberate
**risk-first spike**: background SMS reliability is the thing most likely to sink the
project, so it is proven on a real device before any product UI is built.

### Phase 0 — Scaffold, tooling & CI
`flutter create --platforms=android` (application id `com.rsh.smsscheduler`); DejaPoo folder
layout (`lib/{data,domain,features,ui}`, `packages/`, `tool/`); `analysis_options.yaml` copied
from DejaPoo; theme tokens; go_router shell with bottom nav (**Schedules · History ·
Settings**) and themed empty screens; `tool/ci_version.sh`; GitHub workflows `test.yml`,
`android.yml` (PR prerelease APK + release on main), `claude.yml`, `claude-code-review.yml`;
cloud-session bootstrap (`tool/setup_cloud.sh` + `.claude/settings.json` SessionStart hook
that installs a pinned Flutter SDK and, optionally, the Android cmdline-tools); `bd init` with
the phase epics seeded; README; CLAUDE.md Build & Test made real.
**Exit:** `flutter analyze` clean and `flutter test` green in a cloud session; CI builds a
versioned `sms-scheduler-pr<N>-v<ver>.apk` on the PR; the APK installs and opens on a device.

### Phase 1 — Platform spike: background SMS on a real device
`packages/sms_sender` plugin (send + multipart + SENT result, with a Kotlin unit test where
feasible); `android_alarm_manager_plus` integration with an `AlarmScheduler` interface plus a
fake; manifest permissions and receivers plus a manifest test; a permission/onboarding helper
(SEND_SMS, notifications, exact alarm, battery optimization). A hidden **Diagnostics** screen
offers "Send test SMS to <number> now", "…in 2 min (background)", and "Run a 5-minute cadence
soak for N sends". All results are written to a temporary log.
**Exit (manual device gate by the user):** with the app swiped away, (a) a single delayed send
arrives; (b) a 5-min soak delivers ≥ 12/12 within ±1 min while the screen is off for an hour;
(c) a pending alarm survives a reboot; (d) under forced Doze
(`adb shell dumpsys deviceidle force-idle`) the alarm still fires. Results are recorded in the
handoff, including the device model and Android version. If (b) or (d) fails, stop and
revisit the alarm strategy (e.g. a foreground service) before Phase 2.

### Phase 2 — Domain & data layer
`RecurrenceRule` sealed types + JSON codec + `RecurrenceEngine` (§1, including `DailyWindow`)
with exhaustive tests; `renderMessage` (§5) with its tests;
Drift schema v1 (Schedule, Recipient, SendLog, AppSettings), schema dump + migration test
scaffold; repositories with an injectable clock; volume estimator (sends per 30 min / day);
an adapted `.claude/skills/drift-flutter` skill.
**Exit:** engine tests cover every rule kind and DST/month-end/leap/window/end-condition
boundary in ≥ 2 time zones. Window tests cover daily re-anchoring, the inclusive end, an
overnight window across midnight, a window on a DST-transition day, and window + weekdays.
`renderMessage` tests per §5 pass. Repository CRUD and soft delete are tested; analyze/test
green.

### Phase 3 — Dispatcher & background integration
`dispatchDue()` with claim/missed/grace/rate-guard/pause semantics (§2), sending the
`renderMessage` output (§5) and snapshotting it into the log, the single-alarm
re-arm, re-arm triggers (startup, reboot, time/timezone change, mutation), the cross-isolate UI
refresh (§3), failure notifications, and replacement of the Phase 1 spike wiring with the
real dispatcher.
**Exit:** fake-clock integration tests cover the double-fire race (exactly one send), backlog
after a 3-hour outage (one `missed` per schedule, no burst), rate cap, pause, DST-day daily
schedule, and an "end after N" schedule that stops. Two windowed cases: an
"every 10 min, 8 AM–8 PM" schedule simulated over 48 h sends exactly 73/day with no overnight
sends or `missed` rows, and a late-but-in-grace send's `bodySnapshot` carries the *scheduled*
time prefix. **Manual device gate:** a real 5-min
schedule plus a daily schedule run 24 h with correct history.

### Phase 4 — Schedules UX (the MVP loop)
Schedule list: name, recipients summary, human-readable rule ("Every 15 min, 9 AM–5 PM,
weekdays"), next send countdown, enable toggle, swipe to delete with undo, "Pause all" banner.
Editor: message body; an **"Include reminder time" toggle** (on by default) with a live
rendered preview (`3:45pm reminder: …` using the next occurrence) and a segment counter on
the rendered text (GSM-7 160/153, UCS-2 70/67); recipients via the contact picker and manual
entry (E.164 validation, chips); recurrence builder with presets (5 min · 15 min · 30 min ·
hourly · daily · weekdays · weekly · monthly) plus "Custom". For interval schedules, a
**"Daily window" control** sits right below the interval: "All day" (default) or start/end
time pickers. The list row and summary read e.g. "Every 10 min, 8:00 AM–8:00 PM". Then
weekdays, start and end; a **preview of the next 5 send times** from the engine (which shows
the window wrapping to the next morning); a projected-volume warning that accounts for the
window; "Send test now", which sends the rendered text. Duplicate schedule.
**Exit:** a new recurring schedule can be created in under 30 s; previewed times and rendered
text equal engine/`renderMessage` output (widget tests, including a windowed schedule and
prefix on/off); full CRUD works on a device.

### Phase 5 — History, diagnostics & onboarding
History screen: reverse-chron send log grouped by day, filter by schedule/status, failed-row
detail with error-code explanation and "Retry now". Settings → **Health** panel: each required
permission and its status with a fix-it button, battery-optimization state, next armed alarm
time, last dispatch time, and a link to dontkillmyapp.com for the device's OEM. First-run
onboarding walks through the permissions. Log retention setting. Diagnostics screen stays
behind a developer toggle.
**Exit:** every failure path from Phase 3 tests is visible and explained in the UI; a fresh
install reaches a "healthy" state through onboarding alone.

### Phase 6 — Polish & release readiness
App icon and splash; accessibility pass (semantics on the rule builder and chips, large-text
layout); empty/error/loading states; local backup **export/import** of schedules (JSON via the
share sheet / file picker); "Check for updates" from GitHub Releases (port DejaPoo's
`update_service`); release signing in CI; `docs/INSTALL_ANDROID.md` (sideload, permissions,
OEM battery settings, SMS rate-limit ADB override); README final.
**Exit:** a signed release APK/AAB is published by CI on merge to main; the Phase 1 manual
gates are re-run on the release build.

## Sequencing

0 → 1 → 2 → 3 → 4 → 5 → 6, strictly ordered. Phase 1 gates everything after it. Phase 2 can
technically start before the Phase 1 device gate passes, but **Phase 3 must not**. Manual
device gates (Phases 0, 1, 3, 6) need the user and a physical Android phone with a SIM. The
orchestrator pauses and asks; it never marks a manual gate passed itself.

## Risks

| Risk | Mitigation |
|---|---|
| OEM battery killers (Samsung, Xiaomi, OnePlus) drop alarms | `setAlarmClock` + battery-optimization exemption + Health panel + dontkillmyapp link; the Phase 1 soak is run on the user's actual phone |
| Doze throttling of while-idle alarms at a 5-min cadence | Use `alarmClock: true` (Doze-exempt). Cost: an alarm icon shows in the status bar while a schedule is armed. Verified in the Phase 1 gate |
| Android SMS rate prompt (~30 / 30 min) silently fails background sends | Volume estimator + editor warning + dispatcher hard cap + documented ADB override |
| Duplicate sends (double alarm, UI/alarm race, crash mid-send) | UNIQUE claim key in a transaction before sending; at-most-once per recipient per occurrence |
| Backlog burst after the phone was off | Grace window; older occurrences are logged `missed`, never sent |
| DST / timezone travel shifts reminders | Rule-kind-specific semantics (§1), IANA zone stored per schedule, re-arm on `TIMEZONE_CHANGED`, DST tests in ≥ 2 zones |
| Background isolate can't reach the SMS plugin | `sms_sender` is a real plugin package, so it is auto-registered in every engine. Proven in Phase 1 |
| Two Drift connections (UI + alarm isolate) | WAL + busy timeout; cross-isolate ping + resume refresh (§3) |
| Cloud sessions have no Flutter/Android SDK | Phase 0 bootstrap script + SessionStart hook; CI is the authoritative APK build |
| Dual-SIM phones send from the wrong SIM | v1 uses the default SMS SIM; per-schedule SIM choice is deferred (needs `READ_PHONE_STATE`) |

## Deferred / later ideas
Per-schedule SIM selection; delivery reports; a 24-hour or locale-following time-prefix format;
free-form templating tokens beyond the fixed time prefix (`{date}`, `{n}`); multiple windows
per day; calendar-style "skip holidays"; home-screen widget; quick "snooze schedule for 1 day";
encrypted backup to Drive.

## Resolved decisions (user, 2026-10-27)
1. **App name and application id:** "SMS Scheduler", `com.rsh.smsscheduler`.
2. **Status-bar alarm icon** (`setAlarmClock`): accepted. On by default, with a Settings
   toggle to fall back to exact-while-idle alarms (less reliable under Doze).
3. **Missed-send policy:** skip with a grace window, never catch up.
4. **Minimum interval:** 5 min. The engine enforces it, so changing the floor is a one-line
   change.
5. **Daily send window** and **reminder-time prefix** added as core features (§1, §5).

## Deviation log

_(none yet)_

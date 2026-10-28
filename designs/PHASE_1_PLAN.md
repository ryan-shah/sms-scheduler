# Phase 1 Implementation Plan — Platform spike: background SMS on a real device

> **Approved by the user on 2026-10-28.** Implementation is under way on branch `phase_1`.

**Epic:** `sms-4mv`. Children `.1`–`.9` are created at phase start and chained with
`bd dep add`; run `bd show <id>` for details.
**Authority:** `designs/DESIGN.md` Phase 1, §2 (alarms), §4 (SMS gateway), and Permissions &
manifest. Carries forward `designs/PHASE_0_HANDOFF.md`.
**Branch:** `phase_1`, from `main` after PR #1 merges.

## Exit criteria (from DESIGN.md)
These are a **manual device gate run by the user** on a Pixel 10 with Android 17, with the
app swiped away:
1. A single delayed send ("in 2 min, background") arrives.
2. A 5-min soak delivers ≥ 12/12 sends within ±1 min while the screen is off for an hour.
3. A pending alarm survives a reboot.
4. Under forced Doze (`adb shell dumpsys deviceidle force-idle`) the alarm still fires.

Results go in the handoff, with device model and Android version. **If 2 or 4 fails, stop
and revisit the alarm strategy (e.g. a foreground service) before Phase 2.**

The automated criteria:
- `flutter analyze` is clean.
- `flutter test --timeout 30s` is green.
- The sms_sender Kotlin unit test passes.
- CI builds the PR APK.

## Pre-made decisions (implement, don't re-litigate)
- **`packages/sms_sender` is a real Flutter plugin package** (Kotlin, `com.rsh.sms_sender`),
  referenced from the app's pubspec by `path:`. It is never a MainActivity channel, because
  only plugins are registered in the alarm's background engine.
- **Sending:**
  - Get the SmsManager via `context.getSystemService(SmsManager::class.java)` on API 31+;
    below that, use `SmsManager.getDefault()`. Optionally pass `subscriptionId` through
    `createForSubscriptionId`.
  - Split with `divideMessage`, then send with `sendMultipartTextMessage`. Each part gets
    its own SENT `PendingIntent` (`FLAG_IMMUTABLE`) with a unique request code, received by
    a dynamically registered receiver (`RECEIVER_NOT_EXPORTED` on API 33+).
  - The aggregate result is `sent` when every part is `RESULT_OK`. Otherwise it is
    `failed`, carrying the first error code. It is `timeout` if not every part reports
    within 30 s.
  - The method returns `{status, errorCode, parts}`. Delivery reports are out of scope.
- **Result aggregation lives in a pure Kotlin class** so JUnit can test it without a
  device. The plugin is a thin wrapper around it.
- **App-side interfaces** live in `lib/data/` and have fakes in `test/fakes/`:
  - `SmsGateway`: a plugin-backed implementation and `FakeSmsGateway`.
  - `AlarmScheduler`: an `android_alarm_manager_plus` implementation and
    `FakeAlarmScheduler`.
  - `PermissionService`: a `permission_handler` implementation and `FakePermissionService`.
  - `Clock`: a system clock and `FakeClock`.

  Phases 2 and 3 build on these interfaces unchanged where possible.
- **Alarms** use
  `AndroidAlarmManager.oneShotAt(time, id, callback, exact: true, wakeup: true,
  alarmClock: true, rescheduleOnReboot: true, allowWhileIdle: true)`.
  - Only one alarm id is used, matching DESIGN §2's single-alarm model.
  - The callback is a top-level `@pragma('vm:entry-point')` function.
  - `AndroidAlarmManager.initialize()` runs in `main()`.
- **Spike state is not Drift.** Drift arrives in Phase 2, so the spike uses two plain files
  in `getApplicationSupportDirectory()` (via `path_provider`, which works in the background
  isolate):
  - `spike_job.json`: the pending job. It holds the target number, the remaining sends, the
    interval, and the next scheduled time.
  - `spike_log.jsonl`: an append-only log. Each row records `scheduledFor`, `firedAt`,
    `status`, `errorCode` and `parts`.

  The Phase 3 dispatcher deletes both files.
- **Soak timing is absolute, not cumulative.** Send k is scheduled at
  `start + k × interval`, and each fire arms the next from the job file. So the log shows
  drift as `firedAt − scheduledFor`, and drift does not compound. The message body includes
  `#k/N` and the scheduled time, so arrivals can be matched on the receiving phone.
- **Diagnostics screen** at `/diagnostics`. It is reachable by tapping the About version
  row 7 times (a developer toggle that is session-only for now; Phase 5 makes it a real
  setting). It contains:
  - a phone-number field (E.164 entered by hand; no contact picker yet)
  - "Send test SMS now"
  - "Send in 2 min (background)"
  - "Run 5-min soak for N sends" (default 13, so 12 intervals cover an hour)
  - "Cancel job"
  - each permission's status, with a request button
  - the battery-optimization state
  - the next armed alarm time
  - a log viewer with copy-to-clipboard
- **Manifest** gets the full DESIGN.md list now:
  - permissions: `SEND_SMS`, `USE_EXACT_ALARM`, `SCHEDULE_EXACT_ALARM`
    (`maxSdkVersion=32`), `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `POST_NOTIFICATIONS`,
    `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
  - the `android_alarm_manager_plus` `AlarmService`, `AlarmBroadcastReceiver` and
    `RebootBroadcastReceiver` (enabled)

  Each entry is asserted in the new `test/android/android_manifest_test.dart`. The
  `TIMEZONE_CHANGED`/`TIME_SET` receiver waits for Phase 3.
- **New dependencies** are `android_alarm_manager_plus`, `permission_handler` and
  `path_provider`. Each is added only by the issue that needs it and pinned exactly.
  Existing pins are not bumped; on a solver conflict, stop and report.

## Issues (sequential, one sub-agent each)

| # | Issue | Reads | Acceptance (runnable) |
|---|---|---|---|
| .1 | `packages/sms_sender` plugin: Kotlin send + multipart + SENT aggregation, Dart API | DESIGN §4; this plan's "Sending" decision | `cd android && ./gradlew :sms_sender:testDebugUnitTest` passes (aggregator: all-OK, one-part-fails, timeout, single-part). Dart method-channel test with a mock handler maps results. `flutter analyze` is clean in the package and the app |
| .2 | Manifest permissions + alarm receivers + `android_manifest_test.dart` | DESIGN Permissions & manifest | One test assertion per permission, service and receiver, including `maxSdkVersion=32` and the reboot receiver enabled. `flutter build apk --debug` succeeds |
| .3 | `SmsGateway` interface, plugin implementation, `FakeSmsGateway`; `Clock` + `FakeClock` | .1 output, DESIGN §4 | Unit tests: the fake records calls and returns scripted results; the plugin gateway maps the result DTO correctly (mock channel) |
| .4 | `AlarmScheduler` interface, `android_alarm_manager_plus` implementation, `FakeAlarmScheduler`; `initialize()` in `main()`; top-level callback stub | DESIGN §2 | Unit tests: the fake records `armAt`/`cancel` with a single id; the implementation passes `alarmClock`/`exact`/`wakeup`/`rescheduleOnReboot` (verified through a thin injectable seam) |
| .5 | `PermissionService` (SEND_SMS, notifications, exact-alarm status, battery optimization) + fake + Riverpod providers | DESIGN Permissions | Unit tests over the fake for each status mapping. No real permission prompts in tests |
| .6 | Spike store: `spike_job.json` + `spike_log.jsonl` (read/write/append/clear), safe across isolates | this plan's "Spike state" decision | Tests on a temp dir: a job round-trips, log rows append in order, a corrupt or missing file yields empty state |
| .7 | `SpikeRunner`: the alarm callback logic, i.e. load the job, send through the gateway, log the result, arm the next absolute time, finish after N | .3–.6 | Fake clock/gateway/alarm tests: 13-send soak arms `start+k·5min` exactly; a late fire logs drift and arms the next absolute slot without catch-up; a failed send is logged and the soak continues; cancel clears the job and the alarm |
| .8 | Diagnostics screen + hidden entry (7 taps on the About version) + route | .5–.7, `lib/ui/routing/` | Widget tests with fakes: the 7-tap reveal; each button calls the right runner method; permission rows render statuses; the log viewer lists rows |
| .9 | **Manual gate (user):** criteria 1–4 on the Pixel 10 / Android 17 | this plan's "Manual gate" section | User reports results; recorded verbatim in `PHASE_1_HANDOFF.md` |

## Gates
```bash
flutter analyze
flutter test --timeout 30s
(cd android && ./gradlew :sms_sender:testDebugUnitTest)
flutter build apk --debug
```
**Manual gate (`.9`, user):** install the PR APK and open Diagnostics (tap the About version
7×). Grant SEND_SMS and notifications, and exempt the app from battery optimization. Use a
second phone, or your own number, as the target.
1. **Delayed send:** tap "Send in 2 min (background)", then swipe the app away from Recents.
   Expect one SMS about 2 minutes later.
2. **Soak:** start a 13-send soak, swipe the app away, turn the screen off, and leave the
   phone for over an hour. Count the arrivals and their times (≥ 12/12 within ±1 min), then
   copy the log from Diagnostics.
3. **Reboot:** arm "Send in 2 min", wait about 1 minute, then run `adb reboot`. Expect the
   SMS after boot. Check that the alarm is armed with
   `adb shell dumpsys alarm | grep -A3 com.rsh.smsscheduler`.
4. **Doze:** arm "Send in 2 min", turn the screen off, then run
   `adb shell dumpsys deviceidle force-idle` and confirm with
   `adb shell dumpsys deviceidle get deep`, which should print `IDLE`. Expect the SMS on
   time. Afterwards run `adb shell dumpsys deviceidle unforce`.

## Risks & watch-items
| Risk | Mitigation |
|---|---|
| Android 17 tightens exact-alarm or background-start rules beyond DESIGN's assumptions | The gate runs on the real Pixel 10 / Android 17. If it fails, escalate and propose a foreground-service alternative; don't silently change strategy |
| `android_alarm_manager_plus` doesn't support a background-engine plugin call on this Flutter/Android version | Issue .7 is device-proven at gate 1. If the plugin isn't reachable, escalate (DESIGN Risks row) |
| SMS rate prompt during the soak | 13 sends in about an hour is well under ~30 per 30 min |
| The SENT PendingIntent never returns (no signal or airplane mode) | 30 s timeout → `timeout` status in the log |
| Status-bar alarm icon while armed | Accepted (DESIGN resolved decision 2) |
| Gradle unit tests for a path plugin are awkward to run from the app | Fallback: run `./gradlew test` inside `packages/sms_sender/android` with a minimal settings file. Record the working command in CLAUDE.md |

## Deferred / out of scope
- Drift, the recurrence engine and `renderMessage`: Phase 2.
- The real dispatcher, the claim log, and the TIMEZONE_CHANGED/TIME_SET receiver: Phase 3.
- The contact picker and E.164 parsing (`phone_numbers_parser`): Phase 4. The spike takes a
  typed number.
- Notifications (`flutter_local_notifications`) and the Health panel: Phase 5.
- A persistent developer toggle: Phase 5.
- Dual-SIM selection: deferred per DESIGN.

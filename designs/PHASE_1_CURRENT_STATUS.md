# Phase 1 Current Status

**Phase:** 1 — Platform spike: background SMS on a real device (bd epic: `sms-4mv`)
**Last updated:** 2026-10-28

## Done (with verification evidence)
- Plan approved by the user (2026-10-28). Children `sms-4mv.1`–`.9` created and chained.
- `sms-4mv.1` sms_sender plugin (`4a677aa`): root analyze clean, root tests 10/10, package
  tests 4/4, `./gradlew :sms_sender:testDebugUnitTest` green (5 JUnit tests).

- `sms-4mv.2` manifest permissions and alarm components, plus `android_manifest_test.dart`:
  analyze clean, tests 21/21, debug APK built (sub-agent run).

- `sms-4mv.3` `SmsGateway`/`PluginSmsGateway`, `Clock`/`SystemClock`, providers, and the
  fakes in `test/fakes/`: analyze clean, tests 29/29.

- `sms-4mv.4` `AlarmScheduler` + `AndroidAlarmManagerScheduler` (android_alarm_manager_plus
  5.1.2), `alarmCallback` stub in `lib/data/alarms/alarm_callback.dart`, `initialize()` in
  `main()`: analyze clean, tests 32/32, debug APK built (sub-agent run).

- `sms-4mv.5` `PermissionService`/`PermissionHandlerService` (permission_handler 12.0.1),
  `permissionStatusProvider` family, `FakePermissionService`: analyze clean, tests 49/49,
  debug APK built (sub-agent run).

- `sms-4mv.6` `SpikeJob`/`SpikeLogEntry` models and `SpikeStore` (path_provider 2.1.6;
  atomic job writes, one-line log appends, corrupt input tolerated): analyze clean, tests
  57/57, debug APK built (sub-agent run).

- `sms-4mv.7` `SpikeRunner` (`lib/data/spike/spike_runner.dart`), wired into
  `alarmCallback`: analyze clean, tests 65/65.

- `sms-4mv.8` Diagnostics screen (`lib/features/diagnostics/`), the `/diagnostics` route, and
  the 7-tap About-version reveal (`developerModeProvider`, session-only): tests 72/72.
- Full automated gate run by the orchestrator, 2026-10-28: `flutter analyze` clean; root
  tests 72/72; package tests 4/4; `:sms_sender:testDebugUnitTest` green;
  `flutter build apk --debug` built.

- `sms-4mv.10` (bug found during gate setup): the Diagnostics exact-alarm row always showed
  denied on API 33+ because permission_handler only checks SCHEDULE_EXACT_ALARM, which is
  capped at maxSdk 32. It now reads `AlarmManager.canScheduleExactAlarms()` through the
  UI-only MainActivity channel `com.rsh.smsscheduler/system`. Tests 74/74; debug APK built
  (sub-agent run). The on-device check is pending.

## In progress
- `sms-4mv.9` **manual device gate (user)** — waiting on the user's results.

## Next steps
1. Wait for the user's `sms-4mv.9` results (checklist in PHASE_1_PLAN.md "Manual gate").
   Install the PR #2 CI APK (prerelease `pr-2`) or `build/app/outputs/flutter-apk/app-debug.apk`.
2. If criterion 2 or 4 fails: stop and escalate (alarm-strategy rethink, e.g. a foreground
   service), per PHASE_1_PLAN.md.
3. If all pass: record the results verbatim in `designs/PHASE_1_HANDOFF.md` (template in
   `designs/templates/`), update the README phase table, delete this file, close `.9` and
   `sms-4mv`, push, and mark PR #2 ready.

## Known issues & gotchas
- Gradle needs `JAVA_HOME` (Windows: `C:\Program Files\Android\Android Studio\jbr`).
- The alarm component class names in the manifest were checked against the
  android_alarm_manager_plus 5.1.2 source. Its own manifest declares none of them.
- permission_handler 13.x requires compileSdk 37 and fails locally ("android-37" target not
  found), so it is pinned at 12.0.1. Upgrade tracked as `sms-5rv`.
- path_provider_android 2.3.x is JNI-based. Reaching it from the alarm's background engine
  is first proven on device at gate 1 (`sms-4mv.9`).
- CI doesn't run the package's Dart or Kotlin tests yet (`sms-78o`).

## Decisions made this phase
- 2026-10-28: sms_sender channel `com.rsh.sms_sender`, method `send`; a send exception
  returns `failed` with plugin error code -1000.
- 2026-10-28: the exact-alarm status bypasses permission_handler and uses a MainActivity
  channel. It is UI-only, so CLAUDE.md's background-engine rule doesn't apply.
- 2026-10-28: the first soak send is one interval out (`start = now + interval`); send k fires
  at `start + k*interval`. A fire that is late past later slots skips forward to the next
  future slot; missed slots are not sent. `onAlarm` saves the job and arms the next alarm
  before sending, so a crash mid-send can drop a log row but never double-sends.
  Body: `SMS Scheduler test #k/N scheduled HH:mmZ`.

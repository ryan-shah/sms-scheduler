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

## In progress
- `sms-4mv.8` Diagnostics screen + 7-tap reveal + `/diagnostics` route — dispatched to a sub-agent.

## Next steps
1. `bd ready` → dispatch the next `sms-4mv.N` child with the ORCHESTRATION.md prompt template.
2. After each child: re-run `flutter analyze` and `flutter test --timeout 30s`, commit
   `<bd-id>: <summary>` with `.beads/issues.jsonl`, push `phase_1`, update this file.
3. After `.8`: run the full gate set from PHASE_1_PLAN.md (incl. `flutter build apk --debug`
   and the sms_sender Gradle unit test), then hand `.9` (manual device gate) to the user.

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
- 2026-10-28: the first soak send is one interval out (`start = now + interval`); send k fires
  at `start + k*interval`. A fire that is late past later slots skips forward to the next
  future slot; missed slots are not sent. `onAlarm` saves the job and arms the next alarm
  before sending, so a crash mid-send can drop a log row but never double-sends.
  Body: `SMS Scheduler test #k/N scheduled HH:mmZ`.

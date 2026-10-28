# Installing SMS Scheduler on Android

> Stub: expanded in Phase 6 (polish and release readiness).

## Sideload from GitHub Releases

1. On your phone, open the repository's **Releases** page and download the latest
   `sms-scheduler-v<ver>.apk`. (PR test builds are prereleases named `sms-scheduler-pr<N>-v<ver>.apk`.)
2. Allow your browser or file manager to **install unknown apps** (Settings > Apps > Special
   access > Install unknown apps, or the prompt Android shows on first install).
3. Open the downloaded APK and tap Install. Upgrades install over the top if signed with the
   same key (debug-signed PR builds and release builds differ, so uninstall when switching).

## Permissions the app will request

These arrive in Phase 1 and later; the current shell requests none.

- `SEND_SMS` (runtime): send the reminders from your SIM.
- `POST_NOTIFICATIONS` (runtime, Android 13+): failure notifications.
- `USE_EXACT_ALARM` (Android 13+, auto-granted) / `SCHEDULE_EXACT_ALARM` (Android 12 and
  below): fire schedules at the exact minute.
- `RECEIVE_BOOT_COMPLETED`: re-arm schedules after a reboot.
- `WAKE_LOCK`: finish a send while the screen is off.
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: ask to be exempt from battery optimization.

## Battery optimization (OEM killers)

Samsung, Xiaomi, OnePlus and others may kill background alarms. Exempt the app from battery
optimization and follow your device's steps at <https://dontkillmyapp.com>.

## SMS rate limit override (TODO, verify in Phase 6)

Android prompts or silently blocks after roughly 30 outgoing SMS in 30 minutes. A possible
override over ADB, **unverified**, using the global setting `sms_outgoing_check_max_count`:

```bash
adb shell settings put global sms_outgoing_check_max_count <n>
```

TODO(Phase 6): confirm the setting name, the interval companion setting, and behavior on
current Android versions before documenting this as supported.

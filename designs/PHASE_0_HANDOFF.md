# Phase 0 Handoff

**Phase:** 0 — Scaffold, tooling & CI (bd epic: `sms-odd`, closed 2026-10-28)

## Phase summary
Phase 0 set up an Android-only Flutter app (`com.rsh.smsscheduler`, minSdk 26) with pinned
dependencies and DejaPoo's lints. It has a Material 3 seed theme and a go_router bottom-nav
shell (Schedules · History · Settings) with empty states, and Settings → About shows the CI
version. Around the app it added a cloud bootstrap script with a SessionStart hook, a CI
version script, and four GitHub workflows that build a versioned PR prerelease APK. All work
landed on branch `phase_0` (PR #1), one commit per bd issue.

## Exit criteria — evidence
- `flutter analyze` clean and `flutter test` green in a cloud session — PASS, with a
  substitution. The orchestrator ran locally on Windows 11 with Flutter 3.44.4, not in a
  cloud container. Results:
  - `flutter analyze`: no issues.
  - `flutter test --timeout 30s`: 10/10 passed.
  - CI `test.yml` on ubuntu-latest: green on `82c3736`.

  The Linux install path of `tool/setup_cloud.sh` has not run in a real cloud session yet.
- CI builds a versioned `sms-scheduler-pr<N>-v<ver>.apk` on the PR — PASS. PR #1's `build`
  job passed in 5m06s and published prerelease `pr-1` with the asset
  `sms-scheduler-pr1-v1.0.9.apk`.
- **Manual (user):** the APK installs and opens on a device — PASS. The user reported on
  2026-10-28: *"APK looks good - validated on a Pixel 10 running Android 17."* (`sms-odd.6`)
- README.md updated — PASS: Phase 0 row → Done; features, commands, CI and secrets sections.

## What changed
- `lib/`
  - `main.dart` (ProviderScope) and `app.dart` (`MaterialApp.router`).
  - `app_version.dart`: `APP_VERSION` dart-define, default `dev`.
  - `ui/theme/` (`tokens.dart` with seed `#2F6FED`, spacing/radius; `app_theme.dart`).
  - `ui/routing/`: `appRouterProvider`, a `StatefulShellRoute.indexedStack`, and
    `ScaffoldWithNavBar`.
  - `ui/widgets/empty_state.dart`.
  - `features/{schedules,history,settings}/`.
- `test/`
  - `app_test.dart` (6 shell tests).
  - `android/android_config_test.dart` (4 tests: app id/namespace, MainActivity package,
    minSdk 26, label).
- `android/`: Gradle id `com.rsh.smsscheduler`, MainActivity under
  `kotlin/com/rsh/smsscheduler/`, label "SMS Scheduler".
- `tool/`
  - `setup_cloud.sh`: idempotent. Pins `FLUTTER_VERSION=3.44.4`; `WITH_ANDROID_SDK=1`
    installs android-36 / build-tools 36.0.0; installs bd best-effort.
  - `ci_version.sh`: copied verbatim from DejaPoo commit `02767a7`.
- `.github/workflows/`: `test.yml`, `android.yml`, `claude.yml`, `claude-code-review.yml`.
  All are pinned to Flutter 3.44.4.
- `.claude/settings.json`: a SessionStart hook that runs `setup_cloud.sh` only when
  `CLAUDE_CODE_REMOTE=true`, then `bd prime --hook-json`.
- Docs: `README.md`, CLAUDE.md Build & Test (verified), and the `docs/INSTALL_ANDROID.md` stub.

## How to verify
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --timeout 30s          # expect 10 passed
bash tool/ci_version.sh             # name=1.0.<commits> / code=<commits>
actionlint                          # go install github.com/rhysd/actionlint/cmd/actionlint@latest
flutter build apk --debug
```

## Decisions & deviations from DESIGN.md
- Flutter is pinned to 3.44.4, the local dev SDK, in `tool/setup_cloud.sh` and in every
  workflow.
- Pinned dependencies (exact versions, no carets): flutter_riverpod 3.4.3,
  riverpod_annotation 4.0.7, go_router 18.1.1; dev: riverpod_generator 4.0.9,
  build_runner 2.15.1, flutter_lints 6.0.0.
- The router is a Riverpod `Provider<GoRouter>`, not DejaPoo's global, so each test gets
  fresh nav state. There is no codegen yet.
- `.gitattributes` was written fresh because DejaPoo has none: LF for text, CRLF for `.bat`,
  binaries marked binary.
- `*.g.dart` is gitignored, as in DejaPoo. CI runs `build_runner` before analyze, test and
  build.
- The PR-prerelease cleanup workflow was not ported. It is deferred as `sms-3gj`.
- No deviation from DESIGN.md's design decisions. The only gap is the cloud-session
  verification substitution noted above.

## Deferred work
- `sms-3gj`: port the PR prerelease cleanup, which runs when a PR closes. Until then `pr-N`
  prereleases accumulate.

## Pointers for next phase
- **Secrets to add** in repo Settings → Secrets → Actions. All are optional, and the
  workflows skip gracefully without them:
  - `CLAUDE_CODE_OAUTH_TOKEN`: the Claude workflows.
  - `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`: release signing on
    main. Without them, release APKs are debug-signed.
- Debug-signed PR APKs and future release-signed APKs use different keys. Switching between
  them needs an uninstall.
- CLAUDE.md names `test/android/android_manifest_test.dart`. It doesn't exist yet. Phase 1
  creates it alongside the manifest permissions; keep `android_config_test.dart` for the
  gradle and id checks.
- New dependencies are added only by the issue that needs them, then pinned exactly.
- **bd gotcha:** the remote has no Dolt data, so `bd bootstrap --yes` fails. To recover:
  1. Temporarily blank `sync.remote` in `.beads/config.yaml`.
  2. Run `bd init --prefix sms --reinit-local`.
  3. Run `git checkout -- .beads/`.
  4. Run `bd import`.

  Never use `bd init --from-jsonl`: it deleted the tracked JSONL. This is also in
  `bd memories`.
- Test device: the user's **Pixel 10, Android 17**. The Phase 1 manual gates run on it.

# Phase 0 Implementation Plan — Scaffold, Tooling & CI

**Audience:** the orchestrator dispatching sequential implementation sub-agents (see
`designs/ORCHESTRATION.md`).
**Epic:** `sms-odd` (children `sms-odd.1`–`.6` are created in step 0 below and chained with
`bd dep add`).
**Authority:** `designs/DESIGN.md` Phase 0. Reference implementation: `ryan-shah/DejaPoo`
(copy patterns; don't copy its Drive/web/OAuth/iOS machinery).

## Exit criteria (from DESIGN.md)

1. `flutter analyze` clean and `flutter test --timeout 30s` green **in a cloud session**.
2. CI builds a versioned `sms-scheduler-pr<N>-v<ver>.apk` on the phase PR.
3. **Manual:** the user installs that APK on their phone and it opens to the themed shell.

## Step 0 — orchestrator, before any sub-agent

bd is already initialized (prefix `sms`), and the seven phase epics were seeded on
2026-10-27 (see the table in `ORCHESTRATION.md`). In a fresh container:

```bash
npm install -g @beads/bd            # bd is not preinstalled in cloud containers
bd bootstrap --yes                  # restores the DB from refs/dolt/data or .beads/issues.jsonl
bd ready                            # → sms-odd
bd create --parent sms-odd --acceptance "<from table below>" "Cloud bootstrap: Flutter SDK setup script + SessionStart hook"
# … .2–.6 as listed below, then chain them: bd dep add sms-odd.2 sms-odd.1  (etc.)
bd export -o .beads/issues.jsonl
```
Commit the `.beads/issues.jsonl` export together with any plan edits on `phase_0`.

## Pre-made decisions (implement, don't re-litigate)

- **Project:** `flutter create --platforms=android --org com.rsh --project-name sms_scheduler .`
  That generates `com.rsh.sms_scheduler`, so set `namespace` and `applicationId` in
  `android/app/build.gradle.kts` to **`com.rsh.smsscheduler`**, move `MainActivity.kt` to the
  matching package directory, and set the manifest label to "SMS Scheduler" (DESIGN.md
  resolved decision 1). A manifest/gradle test asserts the id. `minSdk 26`;
  `targetSdk`/`compileSdk` = Flutter default.
- **Flutter version:** pin the current stable release in `tool/setup_cloud.sh` and in the
  workflows (`subosito/flutter-action` with `flutter-version:`), so cloud sessions and CI match.
- **Dependencies, Phase 0 only:** `flutter_riverpod`, `riverpod_annotation`, `go_router`;
  dev: `flutter_lints`, `build_runner`, `riverpod_generator`. Pin to the versions
  `flutter pub get` resolves. No Drift until Phase 2.
- **Lints:** copy DejaPoo's `analysis_options.yaml` verbatim (drop the web/ios excludes that
  don't apply). Copy `.gitattributes`. Start `.gitignore` from DejaPoo's, minus personal-data lines.
- **Theme:** Material 3, `ColorScheme.fromSeed` with a single seed token in
  `lib/ui/theme/tokens.dart` (proposed `#2F6FED`), light + dark following the system setting,
  and DejaPoo's spacing/radius token style.
- **Shell:** go_router `StatefulShellRoute.indexedStack` with bottom `NavigationBar`:
  **Schedules** (`/`), **History** (`/history`), **Settings** (`/settings`). Each has a themed
  empty state. The Schedules FAB is present but disabled ("coming in Phase 4").
- **Versioning:** copy `tool/ci_version.sh` verbatim. `lib/app_version.dart` reads
  `--dart-define=APP_VERSION` (`dev` locally) and Settings → About shows it.
- **CI:** adapt DejaPoo's `test.yml`, `android.yml`, `claude.yml`, `claude-code-review.yml`.
  In `android.yml`, rename artifacts to `sms-scheduler-*`, keep the PR-prerelease and
  release-on-main flow and the release-keystore probe, and **drop** the Google-Sign-In
  CI-test-keystore step. Don't port `deploy_github_page.yml`, `pr_preview*.yml`, or
  `tool/setup_web.dart`.
- **Cloud bootstrap:** `tool/setup_cloud.sh` is idempotent. It installs the pinned Flutter SDK
  to `$HOME/flutter` if missing, runs `flutter precache --android`, and optionally
  (`WITH_ANDROID_SDK=1`) installs the Android cmdline-tools + platform + build-tools and
  accepts licenses. Hosts verified reachable from cloud sessions on 2026-10-27:
  `storage.googleapis.com`, `pub.dev`, `dl.google.com`, `registry.npmjs.org`.
  `bd init` already wrote a `.claude/settings.json` SessionStart hook (`bd prime --hook-json`).
  Extend it so a fresh container gets bd and Flutter first:
  `bash tool/setup_cloud.sh` (installs bd via npm and runs `bd bootstrap --yes` if missing),
  then `bd prime --hook-json`.

## Issues (sequential, one sub-agent each)

| # | Issue | Acceptance (runnable) |
|---|---|---|
| .1 | Cloud bootstrap: `tool/setup_cloud.sh` + `.claude/settings.json` hooks | Fresh container: `bash tool/setup_cloud.sh && flutter --version` prints the pinned version; second run is a no-op (< 5 s) |
| .2 | `flutter create` + pinned pubspec + lints + `.gitignore`/`.gitattributes` | `flutter analyze` clean; default counter app replaced by an `App` widget; `flutter test` green |
| .3 | Theme tokens + go_router shell + three empty screens + Settings → About version | Widget tests: each tab renders its empty state; navigation switches tabs; About shows `dev`; light + dark both build |
| .4 | `tool/ci_version.sh`, `lib/app_version.dart`, the four workflows | `bash tool/ci_version.sh` prints `name=`/`code=`; workflows pass `actionlint` (install via `go install` or the release binary) |
| .5 | Docs: README (status table for Phases 0–6), CLAUDE.md Build & Test made real, `docs/INSTALL_ANDROID.md` stub | Every command in CLAUDE.md's Build & Test section runs successfully in a cloud session |
| .6 | **Manual gate (user):** install the CI PR APK, confirm it opens to the shell | User confirms in chat; result recorded in `PHASE_0_HANDOFF.md` |

Phase closeout (orchestrator): handoff doc, README phase-0 row → Done, close the epic, and
write `PHASE_1_PLAN.md` for user review.

## Risks & watch-items

| Risk | Mitigation |
|---|---|
| Flutter SDK download is slow or large in cloud sessions | Idempotent script with a version marker check; precache Android artifacts only |
| Android SDK absent in cloud → no local APK build | CI `android.yml` is the authoritative APK gate; local `WITH_ANDROID_SDK=1` is optional |
| `actionlint` unavailable | Fall back to reviewing workflows against DejaPoo's known-good versions, and to the PR's CI run |
| Secrets missing in the new repo (`CLAUDE_CODE_OAUTH_TOKEN`, keystore) | Workflows must skip gracefully. The orchestrator lists the secrets the user needs to add in the Phase 0 handoff |

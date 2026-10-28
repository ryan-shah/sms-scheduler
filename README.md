# SMS Scheduler

An Android app that sends recurring SMS reminders from your own phone to any contacts or
numbers, on schedules from **every 5 minutes** to **monthly**, with a full send history. It
sends through your SIM, so it needs no server and no paid SMS provider.

**Target:** Android only (sideloaded APK from GitHub Releases; Google Play restricts the
`SEND_SMS` permission to default SMS apps). See [`docs/INSTALL_ANDROID.md`](docs/INSTALL_ANDROID.md).

## Status

Design and scope: [`designs/DESIGN.md`](designs/DESIGN.md) (authoritative). How phases are
built: [`designs/ORCHESTRATION.md`](designs/ORCHESTRATION.md).

| Phase | Scope | bd epic | Status |
|---|---|---|---|
| 0 | Scaffold, tooling, CI, cloud bootstrap | `sms-odd` | In progress |
| 1 | Platform spike: background SMS proven on a real device | `sms-4mv` | Planned |
| 2 | Domain & data layer: recurrence engine, Drift schema, repositories | `sms-age` | Planned |
| 3 | Dispatcher: single-alarm scheduling, missed/rate/pause policies | `sms-9s4` | Planned |
| 4 | Schedules UX: list, editor, recurrence builder, previews | `sms-jjc` | Planned |
| 5 | History, diagnostics & onboarding | `sms-a43` | Planned |
| 6 | Polish & release readiness | `sms-ty9` | Planned |

## Current features

- Themed Material 3 app shell (light/dark) with a go_router bottom navigation:
  Schedules, History, Settings.
- Empty placeholder screens; Settings shows the app version in About.
- No SMS sending yet (arrives in Phase 1).

## Development

Requires Flutter 3.44.4 (stable) and the Android SDK.

```bash
bash tool/setup_cloud.sh                 # cloud sessions: pinned Flutter SDK (no-op if present)
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --timeout 30s               # always pass --timeout
flutter build apk --debug
flutter build apk --release              # debug-signed without a keystore
bash tool/ci_version.sh                  # version CI will stamp
```

Issue tracking uses [bd (beads)](https://github.com/gastownhall/beads): `bd ready`,
`bd show <id>`. See [`CLAUDE.md`](CLAUDE.md) for contributor and agent rules.

## CI

| Workflow | Trigger | What it does |
|---|---|---|
| `test.yml` | PR, push to main | `flutter pub get`, build_runner, `flutter analyze --no-fatal-infos`, `flutter test --timeout 30s` |
| `android.yml` | PR, push to main | Builds a release APK versioned by `tool/ci_version.sh` (`<MAJOR.MINOR>.<commit count>`). PRs get `sms-scheduler-pr<N>-v<ver>.apk` as an artifact and a `pr-<N>` prerelease; main gets a GitHub Release with `sms-scheduler-v<ver>.apk` and an AAB |
| `claude.yml` | `@claude` mentions | Claude Code assistant on issues/PRs |
| `claude-code-review.yml` | PRs | Automated Claude code review |

### Optional secrets

All are optional; the workflows skip the related step gracefully when unset.

- `CLAUDE_CODE_OAUTH_TOKEN`: enables the two Claude workflows.
- `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`: release signing on main.
  Without them the APK is signed with the debug key.

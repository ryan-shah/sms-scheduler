# Project Instructions for AI Agents

**SMS Scheduler** — an Android-only Flutter app that sends recurring SMS reminders from the
user's own SIM (every 5 min → monthly). Patterns are borrowed from `ryan-shah/DejaPoo`.

## Start here

1. `designs/DESIGN.md` — **authoritative** product scope, architecture, data model, phases.
2. `designs/ORCHESTRATION.md` — how phases are executed by sequential sub-agents.
3. The active `designs/PHASE_X_PLAN.md` and `designs/PHASE_X_CURRENT_STATUS.md`, and the
   previous phase's `PHASE_X_HANDOFF.md`.

If implementation deviates from DESIGN.md, add a dated entry to its deviation log.

## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking (`npm install -g @beads/bd` if missing).
Run `bd prime` for the full workflow.

```bash
bd ready                 # Find available work
bd show <id>             # View issue details
bd update <id> --claim   # Claim work
bd close <id>            # Complete work
```

- Use `bd` for ALL task tracking — no TodoWrite/TaskCreate/markdown TODO lists, and no
  checkbox lists in status/handoff docs (reference bd ids instead).
- Use `bd remember` for persistent knowledge — not MEMORY.md files.

## Build & Test

> Phase 0 (`sms-odd.5`) makes every command here real and verified. Until then this is the
> intended set.

```bash
bash tool/setup_cloud.sh                 # cloud sessions: install pinned Flutter SDK (idempotent)
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze                          # CI uses --no-fatal-infos
flutter test --timeout 30s               # ALWAYS pass --timeout
flutter test --timeout 30s test/path/to/file_test.dart
flutter build apk --debug                # needs Android SDK (WITH_ANDROID_SDK=1 bash tool/setup_cloud.sh)
flutter build apk --release
bash tool/ci_version.sh                  # version CI will stamp: name=<MAJOR.MINOR>.<commits>
```

### Test-run rules (inherited from DejaPoo)

- **Always `--timeout 30s`.** It does not bound `testWidgets` (10-min internal default), so a
  run stalled for minutes is wedged. Kill it; don't wait.
- **Run long suites detached, redirect output to a file, and poll the file.** Never pipe test
  output through `tail`/`head`.
- **Drift + widget tests:** end any widget test whose tree holds live drift `watch()` streams
  with `await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const
  Duration(milliseconds: 1));`.
- **Never call real SMS sending, real AlarmManager, or real permission prompts from tests.**
  Use `FakeSmsGateway`, `FakeAlarmScheduler`, an injectable `Clock`, and permission fakes.
- **Checkpoint `PHASE_X_CURRENT_STATUS.md` before any long run.**

## Android-specific rules

- `packages/sms_sender` must stay a real Flutter **plugin** package. A MainActivity
  MethodChannel is not registered in the alarm's background engine.
- Every manifest permission/receiver the app relies on is asserted in
  `test/android/android_manifest_test.dart`. Add a test line when you add a manifest entry.
- Resolve the device timezone with `flutter_timezone`, never `DateTime.now().timeZoneName`
  (not an IANA id on Android; DejaPoo dp-5br).
- Anything that must be re-armed on app start is watched from the app shell, not only from the
  screen that edits it (DejaPoo dp-5br).
- Instants are stored in UTC. Wall-clock schedule fields live in `rule_json` with the
  schedule's IANA zone (DESIGN.md §Data model).

## Project Structure

```
lib/
  main.dart / app.dart     # entry + MaterialApp.router
  data/                    # Drift db, repositories, platform adapters (sms, alarms, permissions)
  domain/                  # RecurrenceRule, engine, entities (pure Dart, no Flutter imports)
  features/                # schedules/, history/, settings/, diagnostics/
  ui/                      # theme/, routing/, widgets/
packages/sms_sender/       # in-repo Kotlin plugin: SmsManager multipart send
tool/                      # ci_version.sh, setup_cloud.sh
designs/                   # DESIGN, ORCHESTRATION, phase plans/status/handoffs, templates
```

## Session Completion

Work is NOT complete until `git push` succeeds.

1. File bd issues for remaining work.
2. Run the quality gates if code changed (`flutter analyze`, `flutter test --timeout 30s`).
3. Update bd status and `PHASE_X_CURRENT_STATUS.md`.
4. `git pull --rebase && git push && git status` (must be up to date with origin).
5. Hand off: the status doc's "Next steps" must be executable by a zero-context agent.

## Phase completion

1. Verify every exit criterion in DESIGN.md with evidence. Manual device gates are reported
   by the user, never self-certified.
2. Update `README.md` (phase status table, features, commands).
3. Write `designs/PHASE_X_HANDOFF.md` from the template; delete `PHASE_X_CURRENT_STATUS.md`.
4. File deferred work as bd issues; close the children and the epic; push.


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:1105d646 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->

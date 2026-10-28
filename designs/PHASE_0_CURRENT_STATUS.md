# Phase 0 Current Status

**Phase:** 0 — Scaffold, tooling & CI (bd epic: `sms-odd`)
**Last updated:** 2026-10-27 22:15

## Done (with verification evidence)
- `sms-odd.1`: `tool/setup_cloud.sh` (pins Flutter 3.44.4) and a SessionStart hook gated on `CLAUDE_CODE_REMOTE`. Verified: `bash -n` ok; second run 1.3 s no-op. Linux download/Android SDK paths untested locally.
- Phase 0 children `sms-odd.1`–`.6` created and chained (`bd list --parent sms-odd`); export
  committed and pushed on branch `phase_0`.

## In progress
- `sms-odd.2` flutter create + pubspec + lints — dispatched to a sub-agent.

## Next steps
1. `git checkout phase_0 && git pull`; `bd ready` shows the next unblocked child.
2. Dispatch one sub-agent per child in order (`designs/ORCHESTRATION.md` prompt template),
   re-run gates, commit `<bd-id>: <summary>`, push, update this file.
3. After `sms-odd.5`: open the PR from `phase_0` so CI builds the APK, then ask the user to run
   the manual gate `sms-odd.6`.

## Known issues & gotchas
- The git remote has no Dolt data yet, so `bd bootstrap --yes` fails trying to clone it. On a
  fresh machine: blank `sync.remote` in `.beads/config.yaml` temporarily, run
  `bd init --prefix sms --reinit-local`, restore the config and `.beads/issues.jsonl` with
  `git checkout -- .beads/`, then `bd import`. `bd init --from-jsonl` **deleted** the tracked
  `issues.jsonl`, so don't use it.
- The orchestrator runs locally on Windows (Flutter 3.44.4, Android SDK present), not in a
  cloud container.

## Decisions made this phase
- 2026-10-27: Flutter is pinned to **3.44.4**, matching the local dev SDK.
- 2026-10-27: All Phase 0 work lands on branch `phase_0`, and a PR is opened at the end (user request).

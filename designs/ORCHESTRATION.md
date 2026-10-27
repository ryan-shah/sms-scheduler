# Orchestration — building SMS Scheduler with sequential sub-agents

> How the phases in `designs/DESIGN.md` get built. One **orchestrator** session drives the
> work, and **implementation sub-agents** each complete exactly one bd issue, strictly one
> after another. The model is DejaPoo's (`designs/PHASE_N_PLAN.md` + beads + status/handoff
> docs), adapted from parallel waves to a sequential chain.

## Roles

| Role | Does | Never does |
|---|---|---|
| **Orchestrator** (the top-level session) | Writes each `PHASE_N_PLAN.md`, expands the phase epic into bd children, dispatches one sub-agent per issue, verifies gates, commits and pushes, keeps the status doc current, pauses for manual device gates | Writes feature code itself, except trivial fix-ups after a failed gate |
| **Implementation sub-agent** | Claims one bd issue, implements it with tests, runs the gates, closes the issue, and reports back in the fixed format below | Starts a second issue, bumps pinned deps without reporting, edits `DESIGN.md` decisions, pushes |
| **User** | Approves each phase plan, runs manual device gates, answers escalations | — |

## Phase epics (seeded 2026-10-27)

| Phase | Epic | Blocked by |
|---|---|---|
| 0 — Scaffold, tooling & CI | `sms-odd` | — |
| 1 — Platform spike: background SMS on a real device | `sms-4mv` | `sms-odd` |
| 2 — Domain & data layer | `sms-age` | `sms-4mv` |
| 3 — Dispatcher & background integration | `sms-9s4` | `sms-age` |
| 4 — Schedules UX (MVP loop) | `sms-jjc` | `sms-9s4` |
| 5 — History, diagnostics & onboarding | `sms-a43` | `sms-jjc` |
| 6 — Polish & release readiness | `sms-ty9` | `sms-a43` |

Each epic carries its DESIGN.md scope as its description and its exit criteria as acceptance
criteria (`bd show <id>`). Children are created at phase start (step 3 below), never earlier.
In a fresh container, run `npm install -g @beads/bd && bd bootstrap --yes` first.

## Phase lifecycle

```
Phase N start
  1. Orchestrator reads DESIGN.md + PHASE_{N-1}_HANDOFF.md (+ bd memories: `bd memories`)
  2. Writes designs/PHASE_N_PLAN.md (from templates/PHASE_PLAN_TEMPLATE.md):
       pre-made architecture decisions, ordered issue list, gates, risks
  3. Creates bd children: `bd create --parent <epic> ...` + `bd dep add` to chain them
  4. Commits plan + bd export on branch `phase_N`, pushes; opens a draft PR
  5. ── USER REVIEW of PHASE_N_PLAN.md (skip only if the user said "auto-approve plans") ──
For each child issue, in dependency order:
  6. Dispatch ONE sub-agent with the prompt template below
  7. Sub-agent reports → orchestrator re-runs the automated gates itself
  8. Gate green  → commit ("<bd-id>: <summary>"), push, update PHASE_N_CURRENT_STATUS.md
     Gate red    → re-dispatch the same issue with the failure output (max 2 retries),
                   then escalate to the user with the evidence
Phase N end
  9. Run all exit criteria; pause for any MANUAL device gate and wait for user results
 10. Update README phase table; write PHASE_N_HANDOFF.md; delete PHASE_N_CURRENT_STATUS.md
 11. Close children + epic; `bd remember` any gotchas; push; mark PR ready for review
 12. Wait for the user to merge before starting Phase N+1. Phase N+1 branches from updated main
```

Sequential means **no two sub-agents run at once**. Each one starts from the previous one's
pushed commit, so there are no merge conflicts between agents and no shared-lock wedges, and
every agent sees real code instead of guessing at an interface.

## Issue sizing rules (for step 3)

- One issue = one sub-agent context: ~1–3 files of production code plus their tests. Split
  anything larger.
- Each issue lists **acceptance criteria as runnable checks** (a test name, a command, or an
  observable behavior), never "works correctly".
- Pure-Dart logic (recurrence engine, dispatcher policy, volume estimator) gets its own issues,
  ahead of the issues that wire it to Flutter/Android.
- Manual device gates get their own bd issue, assigned to the user (`--assignee` = user), and
  block the phase-closeout issue.

## Sub-agent prompt template

```
You are implementing ONE bd issue in the sms-scheduler Flutter/Android repo.

Issue: <bd-id> — <title>
Run `bd show <bd-id>` for the full description and acceptance criteria, then
`bd update <bd-id> --claim`.

Before writing code, read:
  - CLAUDE.md (build/test commands and test-run rules — mandatory)
  - designs/DESIGN.md sections: <list the relevant §s>
  - designs/PHASE_N_PLAN.md (pre-made decisions — implement them, don't re-litigate)
  - <skill file, e.g. .claude/skills/drift-flutter/SKILL.md, if touching Drift>
  - <files from the previous issue this one builds on>

Constraints:
  - Scope is exactly this issue. If you find other needed work, `bd create` it and mention it.
  - Do not change pinned versions in pubspec.yaml. If a new dependency conflicts, STOP and
    report the solver output instead of force-resolving.
  - Everything must be testable without a device: use the fake SmsGateway / AlarmScheduler /
    Clock. Never call real SMS sending from tests.
  - `flutter test --timeout 30s` always; run it detached with output to a file.

Done means:
  1. `dart run build_runner build --delete-conflicting-outputs` (if codegen touched)
  2. `flutter analyze` → no errors/warnings
  3. `flutter test --timeout 30s` → all green (report the pass count)
  4. `bd close <bd-id> --reason "<one line>"`
  5. Do NOT commit or push; the orchestrator does that after re-verifying.

Report back in exactly this shape:
  STATUS: done | blocked
  FILES: <created/modified paths>
  TESTS: <count passed / new tests added>
  DECISIONS: <anything you chose that the plan didn't specify>
  FOLLOW-UPS: <bd ids you created>
  BLOCKER: <only if blocked: what, evidence, what you need>
```

## Gates

**Automated, after every issue (the orchestrator re-runs them; a sub-agent's word is not enough):**
```bash
flutter analyze
flutter test --timeout 30s
```
**Additionally at phase end:** `flutter build apk --debug` locally if the Android SDK is
present (otherwise rely on CI `android.yml`), and the CI run on the phase PR must be green.

**Manual (user, real phone with a SIM). The orchestrator pauses and asks; it never self-certifies:**
- Phase 0: PR APK installs and opens.
- Phase 1: background send / 5-min soak / reboot / forced Doze (DESIGN.md Phase 1 exit).
- Phase 3: 24 h soak of a 5-min and a daily schedule.
- Phase 6: Phase 1 gates re-run on the signed release build.

For a manual gate, the orchestrator gives the user a short checklist with exact `adb`
commands, then records the reported results verbatim in the handoff.

## Branching & commits

- `main` is protected by convention: each phase lands through a PR from `phase_N`.
- One commit per completed bd issue: `<bd-id>: <imperative summary>`. Push after every
  commit, so a session cutoff never strands more than one issue's work.
- `.beads/issues.jsonl` (the bd export) is committed with each issue close.

## Context-loss resilience

Any session can die mid-phase. `PHASE_N_CURRENT_STATUS.md` (≤100 lines, a snapshot, not a log)
plus `bd ready` must be enough for a fresh orchestrator to resume. Update the status doc after
every issue and before any long-running command. Gotchas go into `bd remember`.

## Escalate to the user (don't guess) when

- A device gate fails, or a platform behavior contradicts DESIGN.md (e.g. alarms throttled
  despite `alarmClock`)
- A dependency conflict needs a pinned-version bump
- An issue has failed its gates after 2 retries
- An implementation needs to deviate from DESIGN.md; then propose the deviation-log entry

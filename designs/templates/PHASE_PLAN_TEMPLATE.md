# Phase X Implementation Plan — <name>

> Copy to `designs/PHASE_X_PLAN.md` at phase start (ORCHESTRATION.md step 2). Written by the
> orchestrator for sequential sub-agents; reviewed by the user before the first dispatch.

**Epic:** `<epic-id>` (children `.1`–`.N`, chained with `bd dep add`; run `bd show <id>`).
**Authority:** `designs/DESIGN.md` Phase X. Carries forward `designs/PHASE_<X-1>_HANDOFF.md`.

## Exit criteria (from DESIGN.md)
1. <criterion — automated or MANUAL>

## Pre-made decisions (implement, don't re-litigate)
- <decision + one-line why>

## Issues (sequential, one sub-agent each)

| # | Issue | Reads | Acceptance (runnable) |
|---|---|---|---|
| .1 | <title> | <DESIGN §, files> | <test names / commands / observable behavior> |

## Gates
```bash
flutter analyze
flutter test --timeout 30s
```
Manual: <device checklist with exact adb commands, or "none">

## Risks & watch-items
| Risk | Mitigation |
|---|---|

## Deferred / out of scope
- <item> — <why>

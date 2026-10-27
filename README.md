# SMS Scheduler

An Android app that sends recurring SMS reminders from your own phone to any contacts or
numbers, on schedules from **every 5 minutes** to **monthly**, with a full send history. It
sends through your SIM, so it needs no server and no paid SMS provider.

**Target:** Android (sideloaded APK from GitHub Releases. Google Play restricts the SEND_SMS
permission to default SMS apps).

## Status

Planning. See [`designs/DESIGN.md`](designs/DESIGN.md) (authoritative design and phase
breakdown) and [`designs/ORCHESTRATION.md`](designs/ORCHESTRATION.md) (how phases are built).

| Phase | Scope | Status |
|---|---|---|
| 0 | Scaffold, tooling, CI, cloud bootstrap | Planned |
| 1 | Platform spike: background SMS proven on a real device | Planned |
| 2 | Domain & data layer: recurrence engine, Drift schema, repositories | Planned |
| 3 | Dispatcher: single-alarm scheduling, missed/rate/pause policies | Planned |
| 4 | Schedules UX: list, editor, recurrence builder, previews | Planned |
| 5 | History, diagnostics & onboarding | Planned |
| 6 | Polish & release readiness | Planned |

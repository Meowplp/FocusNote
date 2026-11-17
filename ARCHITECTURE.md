# FocusNote architecture

## Targets and direction

`FocusNote` (main-actor SwiftUI/AppKit + SwiftData) → `FocusNoteKit`
(Sendable, synchronous value rules with no UI/database dependencies).

- `AppShellView`: Today/History/Analytics navigation and lifecycle entry points.
- `AppModel`: UI selection and task commands. Archived mutations are rejected here,
  not only hidden by views.
- `DailyListStore`: legacy-date migration, active-day identity, immutable archived
  plans, and the archive/create save transaction. Dates/clock and timer-stop closure
  are injectable for deterministic tests.
- `PomodoroController`: monotonic countdown, attempts, recovery, and completion.
  `FocusActivityRecorder` checkpoints one `FocusInterval` per running stretch, in
  the same context/save as the attempt. No database fetches in timer drawing.
- `AnalyticsReader`: SwiftData `@ModelActor`; reads/maps/aggregates away from the UI
  actor. `AnalyticsStore` publishes cached value snapshots and rejects stale loads.
- `FocusAnalytics` / `FocusDayKey` in the library: hour/day allocation, calendar
  boundaries including DST, plan totals, partial-focus accounting, current/best
  streaks. Pure-value unit tests exercise this independently of the app.
- History and Analytics share the same records, not competing counters.

## Persistence

`Item` remains the task/note record, with a stable `dayKey` and optional copied-from
ID. `DailyList` stores civil date identity, creation/migration time-zone provenance,
archive timestamp, and frozen planned seconds. `DailyListState` stores the active
key independently of browsing selection.

`FocusAttempt` is authoritative for outcomes/duration. `FocusInterval` adds precise
active-wall-time placement. Missing legacy duration is retained once as approximate,
never discarded or duplicated. `Item.completedPomodoros` and analytics day summaries
are rebuildable projections; the latter are currently cached in memory.

## Lifecycle and failure boundaries

Launch/main-window reopen invokes rollover; app switching alone does not. Archive
and next-day activation are saved before the fold. The animation cannot create,
delete, or commit records. Repeated checks and crashes after save are idempotent.

A backward system date preserves the active list and shows a retryable explanation.
A new day stops the old timer, preserving partial time without earning fake sessions.
Save errors pause active timing and leave progress available for Retry.

Production uses the local disk container. Self-tests use isolated disk or in-memory
containers; migration verification creates a database with the actual prior binary.
No fixture, benchmark, or snapshot touches the normal user store.

# History/analytics architecture check-in

## Deep daily-history modules — Strong

Signal: a new feature crosses lifecycle, persistence, timer recording, and three
screens. Before this work, daily identity was only a date on each task, with no
persisted active-day state. Attempts stored duration, not pause/resume intervals.

Chosen feature structure: `DailyListStore` owns migration/rollover, an activity
recorder owns intervals, and an off-main reader feeds a pure analytics engine.
This makes archival/relaunch and calendar accounting independently testable.

Interface: `prepare(now:stopTimer:) -> DayRollover?`; a nil result is either
same-day or a surfaced error. Views finish presentation, never the transaction.
Analytics consumes plain Sendable values, with a temporary or in-memory database
as the second, test adapter at the persistence boundary.

Proof: existing timer/checklist tests, new midnight/DST/streak tests, restart and
copy/Undo self-checks, actual old-schema database upgrade, release timer probe,
and active light/dark dashboard snapshots.

## Large timer controller — Worth exploring, deferred

The existing controller is over 400 lines. Its countdown/completion behavior already
has regression coverage. A behavior-only restructuring is not necessary to deliver
the requested feature. Only recorder integration is added there; new archival and
analytics logic stays outside. No unrelated refactor is recommended in this change.

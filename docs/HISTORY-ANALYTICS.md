# Daily history and analytics

## What ships

- Today / History / Analytics navigation (⌘1/2/3). Calendar browses a saved date;
  there is no ambiguous toolbar +. Inline Add Task / Add Note and shortcuts remain.
- Launch or main-window reopening checks a persisted active day. A later day saves
  the previous archive and next active list before the controlled paper fold.
  Same-day return, app switching, and browsing old dates do not end the day.
- No automatic unfinished-task carryover. History offers separate task/note copies
  to the active day with stable provenance, deduplication, and Undo/Redo.
- Saved checklists are read-only, with plans, checkbox states, and session details.
- Analytics is one dashboard, not Day/Week/Month tabs:
  1. Current/best streak and today's qualification.
  2. GitHub-style rolling 52-week heatmap of actual/planned achievement. >80% is
     green, >50% up to 80% light green, ≤50% neutral, and no-plan days outlined.
     Select a cell for date/time/percentage and its weekly chart.
  3. Monday–Sunday vertical hours chart: pale planned bars behind solid green
     actual bars. Values are overlaid from zero, never stacked. Gray dashed planned
     average and green dotted actual average have matching numeric legends.
- Previous/next arrows and This Week navigate the weekly chart. Future weeks are
  disabled. Both averages use the same elapsed-day denominator; completed weeks use
  all seven days, while current-week future days do not dilute the averages.
- Current/best streak: 10 actual minutes earns a calendar day; weekends count.
  Before today qualifies, yesterday's run survives until midnight.

## Accounting and migration

FocusAttempt remains authoritative for duration/outcome. Each Start/Resume creates
one FocusInterval; five-second checkpoints update it in the same save. Pause, reset,
switch, finish, and rollover close it. An interval never spans a pause.

The off-main reader allocates monotonic active seconds over each interval's wall
span, splitting at calendar-hour/day boundaries. It retains the total at DST changes.
Sleep/quit still pause; a forced crash may lose up to the last five seconds.

Legacy attempts lack pause boundaries. Their uncovered actual seconds are retained
once, marked approximate, and assigned to their start date/hour. A resumed legacy
attempt combines that residual with new precise intervals, not duplicate totals.
Significant wall-clock changes also mark placement approximate; duration remains
monotonic. Completed Pomodoros are credited on their completion date, not inferred
from hours or checkboxes.

Task ownership is independent of activity date. Focus after midnight contributes
to the new day's actual time even when its task belongs to the previous list.
Plans are frozen on archive and live while the list remains active. Deleted tasks'
recorded effort stays in actual totals, not erased with the checkbox.

Daily keys are stable Gregorian civil-date strings. Existing task dates are
migrated using the current time zone, explicitly labeled inferred when necessary.
Analytics consistently uses the current reporting zone shown below the dashboard;
travel can regroup activity but cannot rewrite a saved list's identity.

Archive/save failures leave the old list available. A backward system date shows
an explanation instead of silently archiving a future-dated list. A crash after the
rollover transaction opens the saved new day without replaying/duplicating records.
Skipped days appear as zero activity, without manufacturing blank history lists.

## Verification

- `swift test --scratch-path ~/Library/Developer/FocusNote/test-build`:
  38 test functions, including alarm/bell waveforms, midnight, DST, legacy totals, pauses, partial focus,
  strict heatmap boundaries, zero/exceeded plans, fractional planned hours, fair
  weekly averages, streaks and existing timer regressions.
- `tools/selftest.sh`: 141 app checks, including deferred timer creation and saved-frame restoration, rollover, archive immutability,
  copied-task deduplication/Undo, interval checkpoints, background aggregation,
  and unified-dashboard week/heatmap navigation.
- `tools/check-migration.sh`: compiles a portable synthetic legacy schema, creates an old-schema
  database, upgrades with this app, and compares item/attempt counts and total
  active seconds. Temporary stores only; logs are retained.
- `APP_SNAPSHOT_PAGES=all,history,analytics,timer,rollover tools/snap.sh`:
  A clearly named FocusNote Preview copy; light/dark main pages, scrolled details,
  timer states, fold poses, and the fresh next-day list.
- `swift tools/check-dashboard-shots.swift "$shots"`: OCR plus pixel
  checks verify all three sections, weekly bars, both average legends, previous
  weeks, and the rotated Hours axis label.
- `swift tools/check-timer-shots.swift "$shots"`: timer/progress OCR.
  Set `shots` to the private output directory printed by `tools/snap.sh`.
- `tools/grid-lint.sh` and layout probes check static alignment.
- `tools/timer-performance.sh`: release-only isolated timer regression fixture.
- `tools/check-no-screen-recording.sh`: app snapshots render only their own
  AppKit/SwiftUI views. No screen/audio capture APIs or permission requests.

Snapshots no longer use WindowServer/screencapture. This avoids recurring privacy
prompts after ad-hoc rebuilds; native glass/compositor effects are not pixel-exact.
The separate preview bundle cannot touch the real app's store or saved window state.

## Useful manual follow-up

Physical overnight sleep/reopen and travel/time-zone changes; keyboard-only and
full VoiceOver navigation; Reduce Motion; large real histories; actual output
audibility. No cloud sync or export is added in this milestone.

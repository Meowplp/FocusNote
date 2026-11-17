# FocusNote

An offline Mac app combining a paper-like daily checklist with a floating Pomodoro timer and honest planned-versus-actual records.

## Replaces
A paper to-do list and a separate focus timer.

## Main jobs
1. Create a dated daily list with To Do (Pomodoro tasks) and To Remember (plain checkbox notes).
2. Open a task in a floating timer, focus, take configurable breaks, and switch tasks without losing completed sessions.
3. Keep daily history and compare planned versus actual focus in one dashboard with streaks, a plan-completion heatmap, and weekly hours.

## Data
- DailyList: stable civil-date key, time-zone provenance, archive time, frozen planned duration; DailyListState identifies the active day.
- Item: ID, list/date, title, To Do / To Remember kind, completion state; only To Do items have a focus plan.
- Session: ID, task ID, kind (focus/break), planned duration, actual active duration, start/end times, outcome (completed/cancelled).
- FocusInterval: one uninterrupted active stretch, checkpointed with the session; splits precisely across calendar boundaries. Legacy placement is labeled approximate.
- Preferences: default durations, round target, task-completion break, automatic focus/break start settings.

## Shape
Daily checklist window plus one reusable floating timer panel; proposed minimum macOS 26. Local SwiftData storage, offline, no accounts. Working bundle ID: `com.anhpham.focusnote`.

## System hooks
AppKit floating panel across Spaces, with full-screen behavior to verify; optional completion notifications. System calendar/date APIs, not Calendar-event access.

## Reference
User-provided paper checklist image: pale paper, square checkboxes, ruled rows, black lettering. No existing application to clone.

## Look
Minimal monochrome: gray timer background, white clock surface, black numerals. Paper-inspired list with the original system body font for task text, native control typography, restrained borders, accessible contrast, and clear keyboard focus. Compact responsive floating timer.

## Confirmed behavior
- Working name and project folder approved: `FocusNote/`.
- Switching tasks cancels the current Pomodoro; completed Pomodoros remain.
- Reset affects only the current session, never previously completed sessions.
- Focus duration, break duration, round target, and per-task targets are configurable.
- Task names enter inline editing on double-click; Return saves a new task without an Add confirmation button.
- Each task has its own focus, short-break, and long-break durations. The final focus automatically checks it off; its long break follows without delaying completion. Breaks never count as Pomodoros.
- To Remember notes have manual checkboxes, inline edit, delete/Undo, and no timer or focus plan. Existing items stay in To Do; notes never affect planned Pomodoro totals.
- Auto in the timer footer controls the whole sequence, from clicking Play through the final long break. Off means manual starts.
- Work and breaks have different sounds at start/end. Default timer content is 180 × 192 pt; it resizes down to 160 × 168 pt.
- A four-session 25/5/20 plan means four focus sessions, three short breaks, and one final long break, not four short breaks.
- After the final long break finishes or is skipped, a checkmark pops in and turns green; after about 1.2 seconds the timer closes and the To Do list comes forward. Reduce Motion removes the pop. Work start/end plays one three-beep burst; short/long break start/end uses an original iPhone-style notification ding, with mute and previews preserved.
- The toolbar + is removed; inline Add Task/Add Note remain. Today, History, and Analytics use compact segmented navigation.
- On launch/main-window reopen on a later date, archive the previous list, stop its timer preserving partial time, fold its paper away, and reveal a new empty list. Switching apps or browsing history does not roll over.
- History is read-only, with explicit duplicate-safe copying of unfinished tasks/notes to today and Undo. No automatic carryover.
- Analytics is one dashboard: streaks → a rolling 52-week GitHub-style plan-completion heatmap → weekly overlaid planned/actual hours with average lines and week arrows. Above 80% is green, above 50% up to 80% is light green; no-plan days do not earn a percentage. A streak still requires 10 actual minutes; weekends count.

## Proposed defaults to confirm during implementation
25-minute focus, 5-minute short break, 20-minute long break, 4-session target; manual start by default. Cancelled work retains partial active time but earns no completed Pomodoro. Reaching the focus target checks the task off before the long break. Default values remain configurable.

## Not included
- External database integrations and Markdown export.
- Accounts, cloud sync, or collaboration.
- Calendar events, true video PiP, or complex task scheduling.

All data stays local. History and Analytics are implemented; export remains a later step. Detailed accounting and verification: `HISTORY-ANALYTICS.md`.

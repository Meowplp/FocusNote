# FocusNote backlog

Today, History, and Analytics are implemented alongside the To Do/To Remember checklist and floating timer. Analytics is one dashboard with streaks, a plan-completion heatmap, and a weekly hours chart with average lines. There are 141 app self-checks and 38 unit-test functions, plus an opt-in audible sound test. History/analytics accounting and screenshot commands are in HISTORY-ANALYTICS.md. Saved-window launch recovery is covered in STARTUP-CHECKS.md. Physical sleep/wake, full-screen/multiple-display behavior, subjective audibility over other media, and the full VoiceOver audit remain manual; export remains pending.
Proposed defaults: 25-minute focus, 5-minute short break, 20-minute long break, 4-session target, manual start.

## M1 — Daily list and reliable floating focus

## M2 — Daily history and locked-in analytics

### New-day rollover
Acceptance:
- [self] Same-day reopen is unchanged; later-day reopen saves archive + active day before presentation, without deleting items or creating blank skipped days.
- [self] Unfinished timer time is preserved; no fake Pomodoros or completion celebration.
- [self] Pending rollover is idempotent; backward system dates keep the current list.
- [snap] Three paper-fold variants, a clean new list, and archived list details in light/dark.
UX:
- Flow: launch/reopen → check active date → save archive/new day → paper folds → new list; navigation does not trigger rollover.
- Surface: existing page only; stable window/navigation, brief interaction lock; Reduce Motion crossfades.
- States: first launch skips folding; same day restores; save/date errors retain data with Retry.
- Words: “Previous list saved to History.”
- Access: no modal confirmation, no required click to finish; no movement with Reduce Motion.
Status: implemented

### Browse History and copy unfinished work
Acceptance:
- [self] Archived task edit/complete/delete actions are rejected at the model boundary.
- [self] Tasks and notes copy separately, without progress; repeated copying is deduplicated; Undo/Redo preserves originals.
- [snap] Overview, saved checklist, completion counts, frozen plan and session disclosure fit in light/dark.
UX:
- Flow: History → choose date → read checklist/sessions → optionally copy unfinished work → Today; All History returns.
- Surface: main-window page, not a sheet.
- States: empty archive explains rollover; missing date shows empty sections; save errors offer Retry.
- Words: “Saved list · Read-only”, “Copy Unfinished Tasks to Today”, “Copy Unchecked Notes to Today”.
- Access: native buttons and disclosure groups, exact completion labels, keyboard navigation via ⌘2.
Status: implemented

### Locked-in dashboard
Acceptance:
- [unit] Actual time includes partial focus but excludes pauses/breaks; hours/days split at real boundaries, including DST.
- [unit] Ten-minute calendar-day streaks include weekends, preserve yesterday until today's end, and retain best streak.
- [self] Background reader preserves durations without double counting; legacy residuals remain approximate.
- [unit] Heatmap thresholds are strict: >80% green, >50% light green, exactly 50% neutral, exactly 80% light green, no-plan days unscored.
- [unit] Planned 10h 30m stays 10.5 hours; average lines use the same elapsed-day denominator and future plans remain visible without diluting current averages.
- [snap] One page contains streaks, GitHub-style heatmap, and overlaid Monday–Sunday hours with both average lines, previous-week and empty-week states in light/dark.
- [self] Week navigation never indexes replacement data with stale chart indices.
UX:
- Flow: Analytics → streaks → heatmap → weekly chart; select a heatmap cell to inspect its ratio and week; arrows/This Week browse without leaving the dashboard.
- Surface: main-window dashboard with scrolling and no additional windows.
- States: cached content while loading; inline retry; no-plan days never imply success; future heatmap cells/weeks disabled; actual bars may exceed planned bars.
- Words: “Streaks”, “Plan consistency”, “Planned vs actual”, “Average planned”, “Average actual”, “This Week”.
- Access: chart mark values, dashed/dotted line legends, date/ratio heatmap labels; ⌘3, ⌥⌘←/→, and ⌥⌘0 for the current week.
Status: implemented

## Existing timer/checklist stories

### Final break → completion → list
Acceptance:
- [self] Natural completion and skipping the final long break show the same celebration, without adding focus or falsely completing a skipped break.
- [self] After approximately 1.2 seconds the timer closes, persisted recovery clears, and the To Do list comes forward exactly once.
- [self] Switching tasks cancels an old celebration; short breaks never trigger dismissal.
- [snap] Default/minimum sizes show the centered green checkmark in light and dark mode.
- [unit/self] Work plays one strong three-beep burst without repeated groups; breaks use a short, distinct message-notification ding. Both prepare off-main; mute stops/clears cues, and serialized start/end playback remains intact.
UX:
- Flow: final long break ends or Skip Break → checkmark pops in → turns green → timer closes → To Do list opens.
- Surface: replace content inside the existing timer panel, not an extra window or alert.
- States: active break retains controls; done hides Auto/pin/navigation; save errors keep the timer open with Retry.
- Words: “All done”, “Returning to your list”.
- Access: completion text accompanies the status color; Reduce Motion disables scaling/color animation. Full VoiceOver announcement and subjective audible strength remain manual checks.
Status: implemented

### S-001 Add a task to today's list
As the user, I open today's list and add a task.
Screens: today-empty, today-list, today-validation
Acceptance:
- [unit] First launch creates one list using the system calendar date and time zone.
- [self] Adding a nonblank title persists a task across relaunch.
- [snap] The list has paper-like ruled rows, square checkboxes, a date, and an Add Task action.
- [self] Task display and text entry use the original system body font; native controls and countdown fonts remain unchanged.
UX:
- Flow: Add Task or Command-N → inline title → Return saves; Escape cancels.
- Surface: inline row, because entry is repeated within the list.
- States: empty “Plan your day” with Add Task; blank title shows “Enter a task name.”; long titles truncate with full-title help; save errors retain input and offer Retry.
- Words: “Add Task”; help “Add a task to this list (⌘N)”.
- Access: logical keyboard order; VoiceOver labels the title field and task rows.
Status: todo

### S-002 Set a task's planned Pomodoros
As the user, I set a target such as five Pomodoros.
Screens: task-plan, task-plan-invalid
Depends: S-001
Acceptance:
- [unit] Targets accept positive whole numbers and reject zero, negative, fractional, or invalid input.
- [self] The task's target survives relaunch and appears beside completed sessions.
- [self] Valid and temporarily empty numeric fields have the same 360 × 300 pt editor size; explanatory paragraphs are removed and validation occupies reserved space.
UX:
- Flow: task's plan button → enter target → Return saves; Escape cancels.
- Surface: popover for the task's related timer settings.
- States: defaults shown for a new task; invalid input has inline guidance; saving updates “0 of 5”.
- Words: “Planned Pomodoros”; help “Set this task's focus plan”.
- Access: labeled numeric input; progress spoken as “0 of 5 Pomodoros completed”.
Status: todo

### S-003 Start a task's floating timer
As the user, I select a task and start its countdown.
Screens: timer-ready, timer-running, timer-paused
Depends: S-002
Acceptance:
- [self] Selecting a task opens one reusable timer panel with its title, countdown, and completed/target count.
- [unit] Start, Pause, and Resume preserve accurate active elapsed time.
- [unit] Modest callback jitter does not repeat then skip a whole display second; true delayed callbacks catch up accurately without fabricating sessions.
- [self] Refresh timers and App Nap activity exist only while running; modal-panel run-loop mode continues ticking.
- [snap] The timer uses a gray background, white clock surface, and black, monospaced numerals.
- [snap] Default content size is 180 × 192 pt; 160 × 168 pt minimum and 360 × 380 pt expanded layouts keep controls visible with responsive digits.
- [manual] The panel can be dragged, resized within readable bounds, and pinned above ordinary windows without stealing typing focus on each tick.
UX:
- Flow: select task → ready panel → Start → Pause or Resume; Back to List returns without cancelling by itself.
- Surface: panel, because the timer stays beside other work.
- States: ready, running, paused; missing task returns to the list with an explanation; long task names truncate.
- Words: “Start”, “Pause”, “Resume”, “Back to List”, “Keep on Top”.
- Access: all controls keyboard accessible with help; VoiceOver announces state changes, not every second.
Status: todo

### S-004 Configure focus and break lengths
As the user, I choose timer durations and start behavior.
Screens: timer-settings, timer-settings-invalid
Depends: S-003
Acceptance:
- [unit] Positive focus and break durations are required; changes affect future sessions, not an active session.
- [self] The centered Auto footer checkbox controls opening a task, breaks, and subsequent focus together. Off means manual starts; on runs through the final long break.
- [self] Each task stores its own focus, short-break, and long-break durations. Its planned Pomodoro count determines when to offer its long break.
UX:
- Flow: Settings → set defaults → close; task plan popover may override durations.
- Surface: Settings window for persistent preferences; task popover for per-task overrides.
- States: sensible defaults, inline validation, saved feedback, and persistence error with Retry.
- Words: “Focus duration”, “Short break”, “Long break”, “Start focus when opening a task”.
- Access: units are spoken; toggles state their behavior; no unlabeled icon controls.
Status: todo

### S-005 Finish a Pomodoro and take a break
As the user, I finish focus and take a configurable break.
Screens: focus-complete, break-ready, break-running, round-complete
Depends: S-004
Acceptance:
- [unit] A completed focus increments the task's completed count exactly once; breaks never increment it.
- [self] Breaks respect manual/automatic start preferences and can be skipped.
- [self] Reaching the focus target automatically checks the task off and offers its long break, then Plan Complete. To plan additional focus, raise its target and uncheck it.
- [unit] For a 5 × 40-minute plan, 10-minute short breaks follow sessions 1–4; only the configured long break follows session 5.
- [self] A fresh 4 × 25 / 5 / 20 plan saves exactly four focus, three short-break, and one long-break completion, totaling 135 minutes.
- [self] Every focus start/end emits the work cue; every short/long-break start/end emits the distinct rest cue. Mute suppresses cues.
- [manual] Listen to Work and Break previews and a real transition; cues must be distinguishable and sequential, never overlapping.
- [unit] A late timer wake-up finishes only the current session; it never fabricates several focus/break cycles.
UX:
- Flow: focus ends → short break or final long break → Start (unless automatic) or Skip Break → next focus or Plan Complete → Back to List.
- Surface: existing timer panel; no blocking completion alert.
- States: focus complete, break ready/running, round complete; the task checkbox fills at the final focus end, not at break completion.
- Words: “Pomodoro complete”, “Short Break”, “Long Break”, “Skip Break”, “Plan Complete”.
- Access: text and icons convey phase; optional sound is not the only feedback.
Status: todo

### S-006 Switch tasks without losing completed Pomodoros
As the user, I switch tasks and cancel only the current Pomodoro.
Screens: task-switch, timer-cancelled
Depends: S-005
Acceptance:
- [unit] Switching cancels the active focus or break; only one timer can be active.
- [unit] Completed focus sessions remain unchanged; cancelled focus earns no completed Pomodoro.
- [self] Returning starts from the full focus duration, automatically or manually according to the preference.
- [unit] Partial active focus time is retained separately for later reporting.
UX:
- Flow: Back to List → choose another task → current session cancels → selected task's timer opens.
- Surface: inline task selection plus the existing timer panel.
- States: cancellation feedback “Current Pomodoro cancelled”; completed progress remains visible.
- Words: “Switch Task”; help explains that switching cancels the current Pomodoro.
- Access: keyboard task selection and a spoken cancellation result; closing the panel alone does not switch tasks.
Status: todo

### S-007 Reset only the current session
As the user, I restart an individual countdown without deleting completed work.
Screens: timer-reset
Depends: S-006
Acceptance:
- [unit] Reset records the current attempt as cancelled and creates a fresh ready session of the same phase.
- [unit] Reset never changes previous completed sessions or their counts.
UX:
- Flow: Reset Session → fresh full-duration ready countdown → Start.
- Surface: timer panel action with clear help; no destructive history deletion.
- States: reset feedback; Reset Session disabled when there is no current attempt.
- Words: “Reset Session”; help “Restart this countdown; keep completed Pomodoros”.
- Access: labeled keyboard-reachable control; announce the restored duration.
Status: todo

### S-008 Complete a task and optionally take a task break
As the user, I check a task off and take a break after it.
Screens: task-complete, task-break-ready
Depends: S-007
Acceptance:
- [self] Checking the box can complete a task early; completing its final planned focus also automatically checks it off.
- [unit] Completion cancels any unfinished focus without awarding a Pomodoro and preserves all prior work.
- [self] An optional task-completion break uses a configurable duration.
- [unit] Completion at a focus boundary offers only one break, not both a session break and a task break.
- [self] Undo reopens the task but does not silently restart a cancelled timer.
UX:
- Flow: checkbox → completed row → optional task break; Undo reopens the task.
- Surface: inline checkbox and existing timer panel for the break.
- States: checked row with strikethrough; Undo feedback; completed tasks stay visible.
- Words: “Complete Task”, “Break after completing a task”, “Undo”.
- Access: VoiceOver checkbox includes title and completion state; color is not the only signal.
Status: todo

### S-009 Recover safely after interruption
As the user, I keep my work when the app quits, crashes, or the Mac sleeps.
Screens: timer-recovery, persistence-error
Depends: S-008
Acceptance:
- [unit] Timer progress uses a monotonic elapsed-time source, not decrementing a counter on each display tick.
- [self] Phase transitions and checkpoint/outcome updates share a database save; active progress checkpoints every five seconds and flushes on pause, switch, reset, quit, and sleep. A forced crash can lose up to the checkpoint interval, but offline time never earns focus credit.
- [unit] State transitions and completed-session insertion are atomic/idempotent.
- [self] Completed sessions and plans persist across relaunch.
- [self] Proposed policy: sleep pauses focus; relaunch restores an interrupted attempt paused, with no automatic focus credit for time while the app was not running.
- [manual] Sleep/wake, forced termination, system-clock changes, and repeated reopen do not duplicate completed sessions.
UX:
- Flow: reopen → restored list and paused timer → Resume or Reset Session.
- Surface: inline recovery message in the panel; no startup modal.
- States: “Session restored paused”; storage errors retain visible work and offer Retry.
- Words: “Resume”, “Reset Session”, “Unable to save changes. Try again.”
- Access: recovery is announced once; controls retain logical keyboard focus.
Status: todo

### S-018 Automatically check off the task at its focus target
As the user, I see my task checked off as soon as its last planned focus session finishes.
Screens: task-auto-completed-light, task-auto-completed-dark, timer-long-break
Depends: S-005
Acceptance:
- [self] The final focus completion and task checkbox are saved together and visible to a fresh database context.
- [self] Partial work, cancelled attempts, and breaks never prematurely check off a task.
- [self] The final long break continues normally, without cancellation, duplication, or extra focus credit.
- [self] Existing fulfilled task history is checked on reload without replaying a break; To Remember notes are excluded.
- [snap] The checked task retains a timer icon while its long break is pending/running.
UX:
- Flow: final focus ends → task checkbox fills and row gains strikethrough → long break proceeds according to Auto.
- Surface: existing inline checkbox and timer panel; no modal or new action required.
- States: incomplete during earlier focus/breaks; checked before the long break; persistence error stays in the timer with Retry.
- Words: “To Do”, completed checkbox count, “Long Break”.
- Access: native checkbox exposes completion; checking is not conveyed by color alone. Full VoiceOver audit remains manual.
Status: doing

### S-019 Add a plain note to To Remember
As the user, I keep checkbox notes separate from my timed tasks.
Screens: all-light, all-dark, starred-light, starred-dark
Depends: S-001
Acceptance:
- [snap] The daily list always shows To Do and To Remember, including useful empty states.
- [self] Add Note / ⇧⌘N opens note entry; Return creates a dated plain note, and blank Return creates nothing.
- [self] Notes support manual completion, inline rename, soft delete, Undo, and persistence.
- [self] Notes contribute zero planned sessions and reject timer/focus-plan entry points without interrupting active work.
- [snap] Note rows have no timer, Pomodoro count, or Edit Focus Plan action.
UX:
- Flow: Add Note or ⇧⌘N → scroll to focused inline field → Return adds → field stays ready; Escape cancels.
- Surface: second inline section in the same dated list, not a second window or modal.
- States: empty “Keep small reminders here.” with Add Note; checked note uses strikethrough; long notes wrap up to two lines with full-text help; save errors reuse inline Retry.
- Words: “To Remember”, “Add Note”, “Delete Note”; note actions do not mention Pomodoros.
- Access: native checkbox, accessible section header, Return/Escape editing, and the same non-pointer edit action as To Do.
Status: doing

## M2 — Daily history and export

### S-016 Rename a task inline
As the user, I double-click a task title and edit it without opening another window.
Screens: task-rename, today-list
Depends: S-001
Acceptance:
- [self] Rename trims excess whitespace and persists the new title.
- [manual] Return commits, Escape cancels, and a blank title preserves the previous title.
- [manual] Single-click does not edit; dropdown and context menu have no Rename action. A focused title offers Return and an accessibility edit action.
- [self] Undo restores the previous title.
Status: doing

### S-017 Delete a task without deleting its history
As the user, I use a task's action menu to hide it from the daily checklist.
Screens: task-actions, today-list
Depends: S-001
Acceptance:
- [self] Delete hides a task without removing its stored record.
- [self] Undo restores the hidden task.
- [unit] When session tracking exists, deleting the active task cancels its attempt without erasing completed sessions.
- [manual] Context menu and visible action menu expose Delete Task.
Status: doing

### S-010 Create a new day's list
As the user, I press the header plus button to start a dated list.
Screens: new-day, existing-day
Depends: S-009
Acceptance:
- [self] Plus creates today's list using the system date; if it exists, opens it rather than creating a duplicate or inventing tomorrow's date.
- [self] Choosing another date is available through New Day…; existing dates open their existing lists.
- [unit] Previous lists remain stored and unfinished tasks are not silently moved or copied.
- [self] Midnight does not replace a list or stop an active timer without user action.
Status: todo

### S-011 Review a previous day's plan versus actual work
As the user, I open history and compare planned sessions, completed Pomodoros, and actual focus time.
Screens: history, day-summary, history-empty
Depends: S-010
Acceptance:
- [unit] Actual focus time includes partial cancelled attempts, shown separately from completed Pomodoros.
- [self] Each task displays planned sessions, completed sessions, and active focus time; the day shows totals.
- [unit] Sessions remain attributed to their original task/list across midnight and time-zone changes.
- [self] Plan edits do not alter stored session durations; original and latest plan values are retained for future analysis.
Status: todo

### S-012 Export a day as Markdown
As the user, I save a portable copy of a daily list.
Screens: export-save, export-error
Depends: S-011
Acceptance:
- [self] Export… opens the system save panel and writes UTF-8 Markdown containing date, task checkboxes, planned/completed counts, and focus time.
- [unit] Special characters in task titles are escaped correctly.
- [self] Cancelling export changes nothing; write failures show a useful error and retry path.
- [self] Creating a new day preserves the previous list in the database even without an export.
Status: todo

## M3 — macOS polish and release checks

### S-013 Use the timer across desktop Spaces
As the user, I keep the floating timer visible while working elsewhere.
Screens: timer-pinned, timer-unpinned
Depends: S-009
Acceptance:
- [manual] Verify pin/unpin, multiple displays, display removal, Spaces, and supported full-screen combinations.
- [manual] Document any macOS full-screen limitations instead of promising universal overlay behavior.
- [self] Panel placement is restored within visible display bounds.
Status: todo

### S-014 Receive optional completion notifications
As the user, I receive completion feedback without requiring notification permission.
Screens: notification-settings
Depends: S-005
Acceptance:
- [self] Notification permission is requested only after opting in.
- [manual] Focus and break completion remain usable when permission is denied.
Status: todo

### S-015 Use every surface accessibly
As the user, I use the app with keyboard navigation, VoiceOver, and system accessibility settings.
Screens: all light/dark variants, large-content, high-contrast
Depends: S-012, S-013
Acceptance:
- [manual] Complete the core loop keyboard-only and with VoiceOver.
- [snap] Verify readable light/dark treatments, long titles, empty states, and error states.
- [manual] Check Increase Contrast, Reduce Motion, window resizing, and focus indicators.
- [self] Unit tests, app self-tests, and build/snapshot checks pass before release.
Status: todo

## Later
- Analytics dashboards and weekly trends based on preserved sessions and plan history.
- Optional automatic Markdown export to a chosen folder.
- Optional distinct global round system beyond each task's planned Pomodoro target.
- iCloud sync only if needed.

## Dropped
- Accounts, collaboration, subscriptions, and a backend server.
- Video encoding or media playback merely to imitate picture-in-picture.
- Calendar-event integration; system date formatting does not need Calendar permission.

# Countdown checks

## Implemented
- Click a task's play icon to open its timer.
- The list has To Do tasks and To Remember checkbox notes. Add Note / ⇧⌘N supports Return-to-add and double-click edit, with delete/Undo.
- A task checks itself off at the final focus boundary, before any final long-break time. Focus completion, checkbox, and recovery state share one save.
- Existing fulfilled focus history is checked at reload without replaying breaks. Notes remain manual and never create timer history or contribute to planned-session totals.
- Start/Pause/Resume; Reset Session cancels only the current attempt.
- Short breaks between focus sessions; one long break after the final planned focus.
- Centered footer Auto controls task auto-start and every subsequent work/break start. Settings mirrors Auto and controls sounds and an early-completion task break.
- Task text uses the original system body font. Focus Plan removes explanatory text and remains fixed while a number is cleared/retyped.
- Default timer content is 180 × 192 pt (previously 360 × 380); minimum 160 × 168, with scalable digits and compact icon controls.
- Work start/end plays the 980 Hz three-beep burst once (~0.78 seconds), instead of repeating three groups. Short/long break start/end plays an original message-notification ding (~0.9 seconds), replacing fairy dust. Normal output/full app gain, serial queuing, mute/stop, and Settings previews remain unchanged.
- Finishing or skipping the final long break pops a checkmark, turns it green after 220 ms, then closes the timer and reveals To Do after about 1.2 seconds. A new task cancels the old dismissal. Reduce Motion removes the pop/color animation; save failures retain the timer and offer Retry.
- Switching tasks cancels the current attempt; returning prepares a full new focus countdown, preserving completions.
- Completed/cancelled focus and break attempts persist with planned duration, active seconds, timestamps, and task ID.
- Active-plan edits preserve the current session duration and update future phases.
- Sleep notification and quit pause/checkpoint the timer. Relaunch restores paused; no offline focus credit.
- Timer menu: Show Timer ⇧⌘T, Start/Pause/Resume ⇧⌘P, Reset Session ⇧⌘R. These are app shortcuts, not global hotkeys.

## Automated
- `swift test --scratch-path ~/Library/Developer/FocusNote/test-build`: 38 total test functions, including single-burst alarm tests, message ding PCM/fade tests, timer regressions, and history/dashboard accounting.
- `tools/selftest.sh`: 141 checks, including saved-frame startup, single-burst routing, completion timing, recovery, history, and unified-dashboard navigation.
- `FOCUSNOTE_AUDIBLE_TEST=1 tools/selftest.sh`: opt-in speaker test, 143 checks. Plays the work burst and break ding, waits for actual AVAudioPlayer delegate completions, and verifies playback starts off-main. Use `FOCUSNOTE_AUDIBLE_TEST=break` to hear only the message ding. Normal fixtures stay silent. Preview identity/window state are isolated from the personal app.

Break reference: https://www.youtube.com/watch?v=p2rBHjShJjw (“iPhone notification
sound effect (ping/ding)”). The app synthesizes its own message-style chime; it does
not include audio downloaded from YouTube or Apple's original sound asset. An exact
auditory match to the linked recording has not been established.
- `tools/grid-lint.sh` and `swift tools/check-layout.swift "$shots"/*-layout.json`.
- `tools/snap.sh`: ready, Auto, running, paused, minimum, expanded, short break, long break, finished, list, valid/empty-field plan editor, and Settings, in light/dark mode.
- `swift tools/check-timer-shots.swift "$shots"`: Vision checks 16 countdown PNGs, 4 completion PNGs (default/minimum), and 6 intermediate/final/returned-list progress PNGs. Set `shots` to the private directory printed by `tools/snap.sh`.

## Still manual
1. Try a new task with 2 Pomodoros, 1-minute focus, 1-minute short break, and 1-minute long break. Check Auto. Verify focus → short break → focus → long break → complete. The task must check off at the second focus end, before the long break.
2. Pin the panel, work in another app, resize/drag it, and check that ticks do not steal typing focus. Unpin and verify ordinary window stacking.
3. Close the timer panel while running; reopen through the task play button or Timer menu and verify continuity.
4. Close the list window; Back to List must reopen it.
5. Test physical sleep/wake, normal quit/relaunch, and forced quit. Forced crashes may lose up to five seconds since the last active checkpoint.
6. Test multiple displays, display removal, Spaces, and full-screen apps. macOS may limit overlays in some full-screen combinations.
7. Verify keyboard-only/VoiceOver flows and live Timer menu enabled states.
8. Preview both sounds in Settings; verify audibility at the Mac's current output volume. Automated tests validate cue routing and available assets, not what reaches the speakers.
9. Add a To Remember note, check/edit/delete it during a focus session, and verify the active timer is unaffected. Confirm no Pomodoro controls appear on notes and both sections follow the selected day.

Sound is included; notification banners and a history dashboard are not. Records are stored for the later history/export step.

## Visual review
- `timer-ready`, `timer-running`, and `timer-paused`: full countdown digits, readable phase/state labels, and controls fit in both appearances.
- `timer-short-break` and `timer-long-break`: distinct phase labels, correct 10:00/20:00 example durations, and Skip Break visible.
- `timer-finished` / `timer-finished-minimum`: centered green checkmark, “All done” and “Returning to your list” fit in both appearances; timer controls are gone. The task has already been checked since final focus completion.
- `task-returned`: active To Do list reappears with 5 of 5 completed, the timer is dismissed, and completed tasks no longer retain a timer button. Snapshots freeze the celebration for inspection; real dismissal timing is tested separately by the self-test.
- `task-plan` / `task-plan-empty-field`: all four fields fit with units, no explanatory paragraphs, identical dimensions even with temporarily invalid input.
- `timer-minimum` / `timer-expanded`: typography scales; footer Auto remains centered and list/pin controls remain reachable.
- `all`/`starred`: paper checklist remains aligned; play controls sit beside unfinished tasks without clipping titles.
- `task-auto-completed`: To Do task checked and struck through at 5 of 5, with the final-break timer still accessible. To Remember has only checkbox text and its action menu.
- `settings-general`: automatic-start preferences and explanatory text fit. List/Settings snapshots still show inactive chrome; the timer snapshots are active. Full non-timer active-window review is not claimed here.

## Countdown lag investigation

The elapsed-time calculation was accurate, but the 1-second repeating display timer
with 100 ms tolerance could repeat then skip a label when callbacks crossed an
integer boundary. A failing deterministic jitter test reproduced 5 skipped labels
over 120 callbacks. Main-thread sampling also showed database fetches in the timer
view's task getter. No sustained multi-second hang was captured in that short sample.

Changes:
- One-shot refreshes align just after the next visible second boundary, recomputed
  from monotonic elapsed time. Both common and modal-panel run-loop modes work.
- No timer wakes while ready/paused/finished. Active sessions suppress App Nap but
  still allow system sleep, which pauses/checkpoints the timer.
- The selected task is a live cached model reference, not a per-render database fetch.
- Task rows use a rebuildable completed-focus projection, updated atomically with
  completed attempts. They no longer observe/filter all session history on each checkpoint.
- Work/rest sounds keep their serial queue, with AudioServices preparation/playback
  on a separate actor rather than `NSSound.play()` on the main thread.

Release probe: 101 synthetic tasks, 2,000 history attempts, 12 seconds. Before and
after use fresh temporary stores; no real user tasks/history are accessed.

| Measurement | Before | After, trial 1 | After, trial 2 |
| --- | ---: | ---: | ---: |
| Maximum main-loop delay | 78.550 ms | 11.618 ms | 16.957 ms |
| Maximum visible update gap | 1,885.372 ms | 1,001.331 ms | 1,009.937 ms |
| Start → first timer frame | 24.552 ms | 12.963 ms | 13.863 ms |
| Maximum tick work | 4.852 ms | 3.318 ms | 3.882 ms |
| Maximum checkpoint save | 6.401 ms | 3.509 ms | 3.710 ms |
| Draw-time task fetches | 27 | 0 | 0 |
| Skipped labels in live probe | 0 | 0 | 0 |

The bounded-jitter regression changed from 5 skipped labels to 0. The short live
probe improved update gaps but did not reproduce the user's occasional multi-second
skip; it does not prove the OS can never delay the process. Genuine delays must
still catch up to real elapsed time, not slow down the countdown or fabricate sessions.

Repeat after `./build.sh` with `tools/timer-performance.sh`. The app rejects
performance mode without an empty temporary store. System sleep/wake, heavy external
load, and audible playback remain useful manual follow-up checks.

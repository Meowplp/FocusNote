# Saved-window startup regression

## Failure

Normal launches aborted in SwiftUI AttributeGraph while
`TimerPanelController.init` called `setFrameAutosaveName`. The controller was
created inside `AppModel` initialization, itself running during the App's `@State`
graph evaluation. Restoring an AppKit window synchronously re-entered SwiftUI layout.

Temporary-store tests skipped the saved-frame branch, so they missed the crash.
The app signature was valid; screen-recording permissions were unrelated.

## Fix

Controller construction now stores configuration only. The native panel is lazy;
its hosting view is attached before `show()` restores saved geometry. Show runs
from a post-launch task or a user action, not App state initialization.

No user preferences, task/history data, or saved timer position were reset.

## Verification

- A new startup check asserts the main app's timer panel has not been constructed.
- An explicit test autosave name exercises the real restore branch even with a
  temporary database. The test saves/reopens a panel and verifies its dimensions.
  Only its unique test preference key is removed.
- The full working-tree app suite passed 140 checks.
- Normal installed launch succeeded with the user's existing saved frame:
  one running FocusNote process, two visible windows (list + restored timer).
- Permission-free light/dark timer renders, countdown/progress OCR, and layout
  checks passed. No screen-recording API/subprocess was added.

Rule: do not create or restore AppKit windows during SwiftUI App/model state
initialization; test normal window-persistence behavior, not just test-store paths.

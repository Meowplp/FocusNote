import AppKit
import SwiftData
import FocusNoteKit
import SwiftUI

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/FocusNote-self.store ~/Applications/FocusNote.app/Contents/MacOS/FocusNote --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0
    private static var launched = false

    static func runIfRequested(model: AppModel) {
        guard requested && !launched else { return }
        launched = true
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            let context = model.container.mainContext
            func items() -> [Item] { (try? context.fetch(FetchDescriptor<Item>())) ?? [] }
            check("startup leaves the timer panel uncreated until it is needed",
                  !model.timerPanel.isPanelCreated)
            TimerStartupSelfTest.run(model: model) { name, passed in check(name, passed) }

            let before = items().count
            model.addItem()
            check("Add Task adds one task", items().count == before + 1)
            check("the new item is selected", model.selection != nil)

            let selected = items().first(where: { $0.uuid == model.selection })
            check("the selection resolves after saving", selected != nil)
            if let item = selected {
                let undo = UndoManager()
                undo.groupsByEvent = false
                model.rename(item, to: "  Write   proposal ", undo: nil)
                check("renaming cleans the task title", item.title == "Write proposal")
                undo.beginUndoGrouping()
                model.setCompleted(item, true, undo: undo)
                undo.endUndoGrouping()
                check("completing a task checks it off", item.isCompleted)
                undo.undo()
                check("Undo reopens the task", !item.isCompleted)
                undo.beginUndoGrouping()
                model.setDeleted(item, true, undo: undo)
                undo.endUndoGrouping()
                check("deleting a task hides it", item.isTrashed)
                check("deleting preserves the stored task", items().count == before + 1)
                undo.undo()
                check("Undo restores the deleted task", !item.isTrashed)
                let originalPlan = item.focusPlan
                let examplePlan = FocusPlan(sessions: 5, focusMinutes: 40, shortBreakMinutes: 10, longBreakMinutes: 20)
                undo.beginUndoGrouping()
                check("per-task focus plan accepts 5 × 40 with 10/20 minute breaks",
                      model.setFocusPlan(item, to: examplePlan, undo: undo))
                undo.endUndoGrouping()
                check("per-task durations are stored", item.focusPlan == examplePlan)
                undo.undo()
                check("Undo restores all focus plan settings", item.focusPlan == originalPlan)
                model.setFocusPlan(item, to: examplePlan, undo: nil)
                check("invalid focus plans are rejected",
                      !model.setFocusPlan(item, to: FocusPlan(focusMinutes: 0), undo: nil)
                        && item.focusPlan == examplePlan)
                try? context.save()
                let reopened = ModelContext(model.container)
                let saved = try? reopened.fetch(FetchDescriptor<Item>()).first(where: { $0.uuid == item.uuid })
                check("task title and target survive a fresh context", saved?.title == "Write proposal" && saved?.plannedSessions == 5)
                check("all focus and break durations survive a fresh context", saved?.focusPlan == examplePlan)
                check("tasks belong to the selected date", Calendar.current.isDate(item.listDate, inSameDayAs: model.selectedDate))
                let validPlan = NSHostingView(rootView: TaskPlanEditor(item: item).environment(model))
                let emptyPlan = NSHostingView(rootView: TaskPlanEditor(item: item, initialSessions: "").environment(model))
                check("clearing a Focus Plan number never changes the editor size",
                      validPlan.fittingSize == emptyPlan.fittingSize
                        && validPlan.fittingSize == NSSize(width: 360, height: 300))
            }
            check("titles are cleaned", ItemTitle.clean("  Buy   milk ") == "Buy milk")

            // Exercise the same Return key path as typing, not a direct model call.
            if let window = NSApp.windows.first(where: { $0.canBecomeKey && !$0.isSheet && !($0 is NSPanel) }) {
                window.makeKeyAndOrderFront(nil)
                model.addingTask = true
                try? await Task.sleep(for: .seconds(0.3))
                let countBeforeTyping = items().count
                sendKey("Vibecoding", code: 9, window: window)
                sendKey("\r", code: 36, window: window)
                try? await Task.sleep(for: .seconds(0.3))
                check("Return adds the typed task without an Add button",
                      items().count == countBeforeTyping + 1 && items().contains { $0.title == "Vibecoding" })
                let afterReturn = items().count
                sendKey("\r", code: 36, window: window)
                try? await Task.sleep(for: .seconds(0.1))
                check("Return on an empty task does not add a blank task", items().count == afterReturn)
                model.beginAddingReminder()
                try? await Task.sleep(for: .seconds(0.3))
                let beforeNote = items().count
                sendKey("Remember the umbrella", code: 15, window: window)
                sendKey("\r", code: 36, window: window)
                try? await Task.sleep(for: .seconds(0.3))
                let note = items().first { $0.uuid == model.selection && $0.isReminder }
                check("Return adds a plain note in To Remember", items().count == beforeNote + 1 && note?.title == "Remember the umbrella")
                let afterNote = items().count
                sendKey("\r", code: 36, window: window)
                try? await Task.sleep(for: .seconds(0.1))
                check("Return on an empty note does not create a blank note", items().count == afterNote)
                if let note {
                    NoteSelfTest.run(model: model, note: note) { name, passed in check(name, passed) }
                }
            } else {
                check("task entry has a testable window", false)
            }
            TimerSelfTest.run(model: model) { name, passed in check(name, passed) }
            await TimerCompletionSelfTest.run(model: model) { name, passed in check(name, passed) }
            let liveTimer = PomodoroController(container: model.container)
            check("idle timer has no scheduled refresh or App Nap activity",
                  !liveTimer.clockDiagnostics.scheduled && !liveTimer.clockDiagnostics.activity)
            if let item = items().first(where: { !$0.isReminder && !$0.isCompleted && !$0.isTrashed }) {
                liveTimer.preferences.startTaskAutomatically = false
                liveTimer.openTask(item)
                liveTimer.start()
                check("running timer schedules refresh and prevents App Nap",
                      liveTimer.clockDiagnostics.scheduled && liveTimer.clockDiagnostics.activity)
                model.rename(item, to: "Live cached task title", undo: nil)
                check("cached timer task stays live when renamed", liveTimer.task?.title == "Live cached task title")
                try? await Task.sleep(for: .seconds(1.3))
                check("real run-loop timer advances without concurrency crashes", (liveTimer.countdown?.elapsed ?? 0) > 0)
                check("countdown continues in the modal-panel run-loop mode", TimerSelfTest.advancesInModalMode(liveTimer))
                NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
                check("system sleep notification pauses focus", liveTimer.countdown?.status == .paused)
                check("pausing releases refresh timer and App Nap activity",
                      !liveTimer.clockDiagnostics.scheduled && !liveTimer.clockDiagnostics.activity)
                liveTimer.cancelCurrent()
            }
            liveTimer.stopClock()
            check("task text uses the original system body font", NoteStyle.noteFont == .body)
            let audio = PhaseSoundPlayer()
            let preparedWork = await audio.prepare(.work)
            let preparedRest = await audio.prepare(.rest)
            check("distinct work and break sound assets are available",
                  preparedWork && preparedRest && PhaseSoundCue.work.isAlarm && !PhaseSoundCue.rest.isAlarm)
            audio.enqueue(.work)
            audio.enqueue(.rest)
            audio.stop()
            await audio.waitUntilFinished()
            let mutedQueue = await audio.playbackDiagnostics
            check("single work alarm burst and message break chime respect mute and discard queued cues",
                  PhaseSoundCue.work.isAlarm && !PhaseSoundCue.rest.isAlarm && mutedQueue.completed == 0)
            let preparedOffMain = await audio.preparationWasOffMainThread
            check("audio-service preparation runs off the main thread", preparedOffMain)
            check("Pomodoro alarm plays one three-beep burst without repeating groups",
                  AlarmTone(frequency: 980).groups == 1 && AlarmTone(frequency: 980).beepsPerGroup == 3)
            let audibleTest = ProcessInfo.processInfo.environment["FOCUSNOTE_AUDIBLE_TEST"]
            if audibleTest == "1" || audibleTest == "break" {
                print("AUDIO TEST: playing requested phase sounds once")
                if audibleTest != "break" { audio.enqueue(.work) }
                audio.enqueue(.rest)
                await audio.waitUntilFinished()
                let playback = await audio.playbackDiagnostics
                check("requested phase sounds finish through the real audio delegate", playback.completed == (audibleTest == "break" ? 1 : 2))
                check("alarm playback starts off the main thread", playback.offMain)
            }
            let timerMenu = NSApp.mainMenu?.items.first(where: { $0.title == "Timer" })?.submenu
            check("Timer menu exposes Show Timer and Reset Session shortcuts",
                  timerMenu?.items.contains(where: { $0.title == "Show Timer" && $0.keyEquivalent == "t" }) == true
                    && timerMenu?.items.contains(where: { $0.title == "Reset Session" && $0.keyEquivalent == "r" }) == true)
            let fileMenu = NSApp.mainMenu?.items.first(where: { $0.title == "File" })?.submenu
            check("File menu exposes Add Note with Command-Shift-N",
                  fileMenu?.items.contains(where: { $0.title == "Add Note" && $0.keyEquivalent.lowercased() == "n"
                     && $0.keyEquivalentModifierMask.contains([.command, .shift]) }) == true)
            model.sidebar = .analytics
            for offset in [-1, -100, 0, -52, 0] {
                model.analyticsDate = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: .now)!
                try? await Task.sleep(for: .milliseconds(120))
                NSApp.windows.first { $0.canBecomeMain && !($0 is NSPanel) }?.contentView?.layoutSubtreeIfNeeded()
            }
            check("unified dashboard survives week navigation and heatmap replacement",
                  Calendar.current.isDateInToday(model.analyticsDate))
            model.sidebar = .all
            if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
                let png = try? OwnWindowSnapshot.png(window: window)
                let bitmap = png.flatMap { NSBitmapImageRep(data: $0) }
                check("own-window snapshots render without screen-recording APIs",
                      (bitmap?.pixelsWide ?? 0) > 0 && (bitmap?.pixelsHigh ?? 0) > 0)
            } else {
                check("own-window snapshots have a testable window", false)
            }
            await DailyHistorySelfTest.run { name, passed in check(name, passed) }

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    private static func sendKey(_ text: String, code: UInt16, window: NSWindow) {
        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil,
            characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code
        ) else { return }
        NSApp.sendEvent(event)
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}

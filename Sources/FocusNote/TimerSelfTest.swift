import AppKit
import FocusNoteKit
import SwiftData

enum TimerSelfTest {
    static func advancesInModalMode(_ timer: PomodoroController) -> Bool {
        let initial = timer.countdown?.elapsed ?? 0
        let deadline = Date.now.addingTimeInterval(1.3)
        while Date.now < deadline && (timer.countdown?.elapsed ?? 0) <= initial {
            _ = RunLoop.main.run(mode: .modalPanel, before: deadline)
        }
        return (timer.countdown?.elapsed ?? 0) > initial
    }

    static func run(model: AppModel, check: (String, Bool) -> Void) {
        let timer = model.timer
        timer.stopClock()
        timer.preferences.startTaskAutomatically = false
        timer.preferences.startBreaksAutomatically = true
        timer.preferences.startNextFocusAutomatically = true
        let context = model.container.mainContext
        let item = Item(title: "Timer sequence")
        item.plannedSessions = 2
        item.focusMinutes = 1
        item.shortBreakMinutes = 1
        item.longBreakMinutes = 2
        context.insert(item)
        model.save()

        timer.openTask(item, now: 100)
        check("opening a task respects manual start", timer.countdown?.status == .ready)
        timer.start(now: 100)
        timer.pause(now: 130)
        timer.tick(now: 999)
        check("pause excludes non-focus time", timer.countdown?.remaining == 30)
        timer.start(now: 1_000)
        timer.tick(now: 1_030)
        check("focus automatically starts the short break",
              timer.countdown?.phase == .shortBreak && timer.countdown?.status == .running)
        check("a completed focus is recorded exactly once", timer.completedCount(for: item.uuid) == 1)
        check("display projection matches the completed focus history", item.completedPomodoros == 1)
        check("one focus below the target does not check off the task", !item.isCompleted)
        timer.tick(now: 1_030)
        check("repeated callbacks do not duplicate completed sessions", timer.completedCount(for: item.uuid) == 1)
        timer.tick(now: 1_090)
        check("short break automatically starts next focus when enabled",
              timer.countdown?.phase == .focus && timer.countdown?.status == .running)
        check("finishing a short break does not complete the task", !item.isCompleted)
        timer.tick(now: 1_150)
        check("final focus starts only the configured long break",
              timer.countdown?.phase == .longBreak && timer.countdown?.remaining == 120)
        check("the last focus checks off the task before its long break", item.isCompleted)
        let completedFromDisk = try? ModelContext(model.container).fetch(FetchDescriptor<Item>()).first { $0.uuid == item.uuid }
        check("automatic completion is saved with the final focus", completedFromDisk?.isCompleted == true)
        check("completed focus projection is saved atomically", completedFromDisk?.completedPomodoros == 2)
        let recoveryBeforeChecking = (try? context.fetch(FetchDescriptor<FocusAttempt>()).count) ?? 0
        model.setCompleted(item, true, undo: nil)
        check("checking off a task during its final break does not create another break",
              timer.countdown?.phase == .longBreak
                && ((try? context.fetch(FetchDescriptor<FocusAttempt>()).count) ?? 0) == recoveryBeforeChecking)
        model.setCompleted(item, false, undo: nil)
        timer.tick(now: 1_270)
        check("long break finishes the plan without adding focus",
              timer.countdown?.phase == .finished && timer.completedCount(for: item.uuid) == 2)
        check("break completion does not overwrite an explicit checkbox change", !item.isCompleted)

        let other = Item(title: "Switch and recover")
        other.plannedSessions = 2
        other.focusMinutes = 1
        context.insert(other)
        model.save()
        timer.openTask(other, now: 2_000)
        timer.start(now: 2_000)
        timer.tick(now: 2_020)
        timer.reset(now: 2_020)
        check("reset cancels partial focus without awarding a Pomodoro",
              timer.countdown?.remaining == 60 && timer.completedCount(for: other.uuid) == 0 && !other.isCompleted)
        let attempts = (try? context.fetch(FetchDescriptor<FocusAttempt>())) ?? []
        check("cancelled attempts preserve partial actual focus time", attempts.contains {
            $0.taskID == other.uuid && $0.outcome == "cancelled" && $0.activeSeconds == 20
        })
        timer.start(now: 2_100)
        timer.tick(now: 2_160)
        timer.openTask(item, now: 2_160)
        check("switching tasks keeps completed Pomodoros", timer.completedCount(for: other.uuid) == 1)
        timer.openTask(other, now: 2_200)
        check("returning to a task prepares a fresh full countdown", timer.countdown?.remaining == 60)
        timer.start(now: 2_200)
        timer.tick(now: 2_210)
        let restored = PomodoroController(container: Store.makeContainer(), runClock: false)
        check("running checkpoint restores paused without offline credit",
              restored.countdown?.status == .paused && restored.countdown?.remaining == 50)
        timer.cancelCurrent(now: 2_210)
        timer.preferences.startTaskAutomatically = true
        timer.preferences.startBreaksAutomatically = false
        timer.preferences.startNextFocusAutomatically = false
        timer.openTask(other, now: 3_000)
        check("opening a task respects automatic start", timer.countdown?.status == .running)
        timer.tick(now: 3_060)
        check("automatic breaks can be turned off",
              timer.countdown?.phase == .longBreak && timer.countdown?.status == .ready)
        timer.skipBreak(now: 3_060)
        check("Skip Break never increments focus count", timer.completedCount(for: other.uuid) == 2)
        timer.cancelCurrent(now: 3_060)

        let early = Item(title: "Finish task early")
        context.insert(early)
        model.save()
        model.timer.openTask(early)
        model.setCompleted(early, true, undo: nil)
        check("checking off an active task offers its long break",
              timer.countdown?.phase == .longBreak && timer.completedCount(for: early.uuid) == 0)
        model.setDeleted(early, true, undo: nil)
        check("deleting the active task cancels its timer", timer.countdown == nil)
        checkFourSessionAutomaticPlan(model: model, check: check)
    }

    private static func checkFourSessionAutomaticPlan(model: AppModel, check: (String, Bool) -> Void) {
        let timer = model.timer
        let context = model.container.mainContext
        let item = Item(title: "Exact four-Pomodoro regression")
        item.plannedSessions = 4
        item.focusMinutes = 25
        item.shortBreakMinutes = 5
        item.longBreakMinutes = 20
        context.insert(item)
        model.save()
        var cues: [PhaseSoundCue] = []
        timer.preferences.soundsEnabled = true
        timer.soundHandler = { cues.append($0) }
        timer.setAutomaticCycle(true, now: 10_000)
        timer.openTask(item, now: 10_000)
        check("Auto starts focus when Play opens a task", timer.countdown?.status == .running)
        var now = 10_000.0
        var phases: [FocusCountdown.Phase] = []
        for _ in 0..<8 {
            guard let clock = timer.countdown, clock.status == .running else { break }
            phases.append(clock.phase)
            if clock.phase == .longBreak {
                check("four-session task is checked off before any long-break time elapses", item.isCompleted)
            } else if clock.completedSessions < item.plannedSessions {
                check("work below target stays unchecked during \(clock.phase.rawValue)", !item.isCompleted)
            }
            now += clock.remaining
            timer.tick(now: now)
        }
        check("Auto completes exactly four focus, three short breaks, and one long break",
              phases == [.focus, .shortBreak, .focus, .shortBreak, .focus, .shortBreak, .focus, .longBreak]
                 && timer.countdown?.phase == .finished)
        check("completed task stays checked after its long break", item.isCompleted)
        let records = ((try? context.fetch(FetchDescriptor<FocusAttempt>())) ?? []).filter {
            $0.taskID == item.uuid && $0.outcome == "completed"
        }
        check("history stores four 25-minute work sessions",
              records.filter { $0.phase == "focus" && $0.activeSeconds == 1_500 }.count == 4)
        check("history stores only three 5-minute short breaks",
              records.filter { $0.phase == "shortBreak" && $0.activeSeconds == 300 }.count == 3)
        check("history stores exactly one final 20-minute long break",
              records.filter { $0.phase == "longBreak" && $0.activeSeconds == 1_200 }.count == 1)
        check("the whole plan totals 135 minutes, with breaks excluded from Pomodoros",
              records.reduce(0) { $0 + $1.activeSeconds } == 135 * 60
                && timer.completedCount(for: item.uuid) == 4)
        check("each work start and end emits the work sound",
              cues.filter { $0 == .work }.count == 8)
        check("each break start and end emits the different break sound",
              cues.filter { $0 == .rest }.count == 8)
        timer.cancelCurrent(now: now)
        model.setCompleted(item, false, undo: nil)
        item.completedPomodoros = 0
        model.save()
        let reopenedContainer = Store.makeContainer()
        _ = PomodoroController(container: reopenedContainer, runClock: false)
        let reconciled = try? reopenedContainer.mainContext.fetch(FetchDescriptor<Item>()).first { $0.uuid == item.uuid }
        check("existing fulfilled tasks are checked on reload without replaying breaks", reconciled?.isCompleted == true)
        check("completed display projection is rebuilt from authoritative history", reconciled?.completedPomodoros == 4)
        timer.setAutomaticCycle(false, now: now)
        let next = Item(title: "Footer Auto checkbox")
        context.insert(next)
        model.save()
        timer.openTask(next, now: now)
        timer.setAutomaticCycle(true, now: now)
        check("checking Auto starts a ready countdown and enables every transition",
              timer.automaticCycleEnabled && timer.countdown?.status == .running)
        timer.setAutomaticCycle(false, now: now)
        check("unchecking Auto makes all following transitions manual",
              !timer.preferences.startTaskAutomatically && !timer.preferences.startBreaksAutomatically
                && !timer.preferences.startNextFocusAutomatically)
        timer.cancelCurrent(now: now)
        cues.removeAll()
        timer.preferences.soundsEnabled = false
        timer.openTask(next, now: now)
        timer.start(now: now)
        timer.tick(now: now + 1_500)
        check("the sound setting silences all automatic cues", cues.isEmpty)
        timer.cancelCurrent(now: now + 1_500)
        timer.soundHandler = nil
    }
}

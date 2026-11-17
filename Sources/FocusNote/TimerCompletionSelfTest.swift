import AppKit
import SwiftData

enum TimerCompletionSelfTest {
    static func run(model: AppModel, check: (String, Bool) -> Void) async {
        let timer = model.timer
        let panel = model.timerPanel.panel
        let previousReveal = timer.revealList
        var returns = 0
        timer.revealList = {
            returns += 1
            model.sidebar = .all
        }
        defer {
            timer.cancelCurrent()
            timer.revealList = previousReveal
            panel.orderOut(nil)
        }
        timer.setAutomaticCycle(false)
        timer.automaticallyDismissCompletion = true

        func prepare(_ title: String, sessions: Int = 1) -> Item {
            let item = Item(title: title)
            item.plannedSessions = sessions
            item.focusMinutes = 1
            item.shortBreakMinutes = 1
            item.longBreakMinutes = 1
            model.container.mainContext.insert(item)
            model.save()
            timer.openTask(item, now: 0)
            model.timerPanel.show()
            timer.start(now: 0)
            timer.tick(now: 60)
            return item
        }

        let natural = prepare("Natural completion animation")
        check("final focus waits for the long break before celebrating",
              natural.isCompleted && timer.countdown?.phase == .longBreak && timer.completionID == nil)
        timer.start(now: 60)
        timer.tick(now: 120)
        let naturalID = timer.completionID
        check("natural long-break completion presents a checkmark before closing",
              naturalID != nil && !timer.completionConfirmed && panel.isVisible && returns == 0)
        timer.tick(now: 121)
        check("repeated completion ticks do not restart the celebration", timer.completionID == naturalID)
        try? await Task.sleep(for: .milliseconds(400))
        check("completion checkmark turns green while the timer is still visible",
              timer.completionConfirmed && panel.isVisible && returns == 0)
        model.sidebar = .starred
        try? await Task.sleep(for: .milliseconds(1_100))
        check("celebration closes the timer and opens To Do exactly once",
              !panel.isVisible && timer.countdown == nil && timer.taskID == nil && returns == 1 && model.sidebar == .all)
        let recovery = try? model.container.mainContext.fetch(FetchDescriptor<TimerRecovery>()).first
        check("dismissed completion clears persisted timer recovery", recovery?.taskID == nil && recovery?.state == nil)
        if let naturalID { timer.finishCompletion(id: naturalID) }
        check("a stale completion callback cannot reopen the list", returns == 1)

        let skipped = prepare("Skip running final break")
        timer.start(now: 60)
        timer.skipBreak(now: 80)
        check("skipping the running final break presents the same completion",
              skipped.isCompleted && timer.completionID != nil && timer.completedCount(for: skipped.uuid) == 1)
        let attempts = (try? model.container.mainContext.fetch(FetchDescriptor<FocusAttempt>())) ?? []
        check("skipped long break retains partial time without claiming completion",
              attempts.contains { $0.taskID == skipped.uuid && $0.phase == "longBreak"
                  && $0.outcome == "cancelled" && $0.activeSeconds == 20 })
        try? await Task.sleep(for: .milliseconds(1_500))
        check("skipped final break automatically closes and returns to the list", !panel.isVisible && returns == 2)

        _ = prepare("Skip unstarted final break")
        timer.skipBreak(now: 60)
        let staleID = timer.completionID
        check("skipping an unstarted final break also celebrates", staleID != nil)
        let next = Item(title: "Do not close my next timer")
        model.container.mainContext.insert(next)
        model.save()
        timer.openTask(next, now: 60)
        if let staleID { timer.finishCompletion(id: staleID) }
        try? await Task.sleep(for: .milliseconds(1_500))
        check("switching tasks cancels the previous completion dismissal",
              timer.taskID == next.uuid && timer.completionID == nil && panel.isVisible && returns == 2)
        timer.cancelCurrent(now: 60)

        _ = prepare("Short break is not the end", sessions: 2)
        timer.skipBreak(now: 60)
        check("skipping a short break never celebrates or closes the timer",
              timer.completionID == nil && timer.countdown?.phase == .focus && panel.isVisible && returns == 2)
        timer.cancelCurrent(now: 60)
    }
}

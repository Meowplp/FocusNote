import Foundation
import SwiftData
import FocusNoteKit

enum DailyHistorySelfTest {
    static func run(check: (String, Bool) -> Void) async {
        do {
            let container = try ModelContainer(for: Item.self, FocusAttempt.self, TimerRecovery.self,
                TimerPreferences.self, DailyList.self, DailyListState.self, FocusInterval.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let model = AppModel(container: container)
            defer { model.timer.stopClock() }
            let calendar = FocusDayKey.calendar()
            let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!
            let yesterdayKey = FocusDayKey.key(yesterday)
            let old = Item(title: "Unfinished yesterday")
            old.listDate = yesterday
            old.plannedSessions = 2
            old.focusMinutes = 25
            old.completedPomodoros = 1
            container.mainContext.insert(old)
            let note = Item(title: "Old reminder", isReminder: true)
            note.listDate = yesterday
            container.mainContext.insert(note)
            try container.mainContext.save()
            try model.dailyLists.bootstrap(now: yesterday)
            check("migration gives legacy tasks stable daily keys", old.dayKey == yesterdayKey && note.dayKey == yesterdayKey)
            check("first daily bootstrap preserves existing tasks", model.dailyLists.activeKey == yesterdayKey)
            model.openDailyList(now: .now)
            check("new-day reopening archives old list before animation",
                  model.rollover != nil && model.dailyLists.archivedKeys.contains(yesterdayKey))
            check("rollover does not delete tasks or carry them forward",
                  old.dayKey == yesterdayKey && old.completedPomodoros == 1
                    && ((try? container.mainContext.fetchCount(FetchDescriptor<Item>())) == 2))
            check("archived checklist rejects edits", !model.canEdit(old))
            model.rename(old, to: "Should not change", undo: nil)
            check("archived rename is blocked in the model", old.title == "Unfinished yesterday")
            model.setCompleted(old, true, undo: nil)
            model.setDeleted(old, true, undo: nil)
            let editedArchivedPlan = model.setFocusPlan(old, to: FocusPlan(focusMinutes: 40), undo: nil)
            check("archived completion, deletion, and focus-plan edits are blocked",
                  !old.isCompleted && !old.isTrashed && !editedArchivedPlan && old.focusMinutes == 25)
            let reopenedStore = DailyListStore(context: ModelContext(container))
            try reopenedStore.bootstrap()
            check("a reopened store restores committed rollover without replay",
                  reopenedStore.activeKey == FocusDayKey.key(.now) && reopenedStore.archivedKeys.contains(yesterdayKey)
                    && reopenedStore.prepare(stopTimer: { false }) == nil && reopenedStore.error == nil)
            let originalTransition = model.rollover?.id
            model.openDailyList()
            check("repeated reopening cannot duplicate a pending rollover", model.rollover?.id == originalTransition)
            model.finishRollover()
            let todayKey = FocusDayKey.key(.now)
            check("animation completion reveals the new active date", FocusDayKey.key(model.selectedDate) == todayKey)
            model.openDailyList()
            check("same-day reopening never folds again", model.rollover == nil)
            let archived = try container.mainContext.fetch(FetchDescriptor<DailyList>()).first { $0.key == yesterdayKey }
            check("archived plan freezes task durations but excludes notes", archived?.plannedSeconds == 3_000)
            model.copyUnfinished(from: yesterdayKey)
            model.copyUnfinished(from: yesterdayKey)
            let copied = try container.mainContext.fetch(FetchDescriptor<Item>()).filter { $0.dayKey == todayKey }
            check("copying unfinished tasks is deduplicated and resets progress",
                  copied.count == 1 && copied.first?.completedPomodoros == 0 && copied.first?.isCompleted == false
                    && copied.first?.copiedFromID == old.uuid && copied.first?.focusMinutes == 25)
            let undo = UndoManager()
            undo.groupsByEvent = false
            undo.beginUndoGrouping()
            model.copyUnfinished(from: yesterdayKey, notes: true, undo: undo)
            undo.endUndoGrouping()
            check("unchecked notes copy only through their separate action",
                  try container.mainContext.fetch(FetchDescriptor<Item>()).filter { $0.dayKey == todayKey && $0.isReminder }.count == 1)
            undo.undo()
            check("copying to today supports Undo without changing the archived note",
                  try container.mainContext.fetch(FetchDescriptor<Item>()).filter {
                      $0.dayKey == todayKey && $0.isReminder && !$0.isTrashed
                  }.isEmpty && !note.isTrashed)
            undo.redo()
            check("Redo restores copied notes with no extra copies",
                  try container.mainContext.fetch(FetchDescriptor<Item>()).filter {
                      $0.dayKey == todayKey && $0.isReminder && !$0.isTrashed
                  }.count == 1)
            let before = model.dailyLists.activeKey
            model.openDailyList(now: yesterday, animate: false)
            check("a backward system date preserves the current list",
                  model.dailyLists.activeKey == before && model.dailyLists.error != nil)
            model.openDailyList()

            let timer = model.timer
            timer.setAutomaticCycle(false)
            let task = copied[0]
            timer.openTask(task, now: 0)
            timer.start(now: 0)
            timer.pause(now: 20)
            timer.start(now: 100)
            timer.tick(now: 130)
            timer.cancelCurrent(now: 130)
            let intervals = try container.mainContext.fetch(FetchDescriptor<FocusInterval>())
            check("pause and resume create separate active intervals", intervals.count == 2)
            check("active intervals exclude the paused gap", intervals.reduce(0) { $0 + $1.activeSeconds } == 50)
            let reader = AnalyticsReader(modelContainer: container)
            let report = try await reader.load()
            check("background analytics preserves partial focus without double counting",
                  abs(report.days.values.reduce(0) { $0 + $1.focus } - 50) < 0.001
                    && report.days.values.reduce(0) { $0 + $1.pomodoros } == 0)
            check("partial focus remains separate from completed Pomodoros",
                  abs(report.days.values.reduce(0) { $0 + $1.partial } - 50) < 0.001)

            let legacy = Item(title: "Resumed legacy attempt")
            legacy.dayKey = todayKey
            legacy.focusMinutes = 1
            container.mainContext.insert(legacy)
            let legacyAttempt = FocusAttempt(taskID: legacy.uuid, phase: "focus", plannedSeconds: 60)
            legacyAttempt.startedAt = yesterday
            legacyAttempt.activeSeconds = 20
            container.mainContext.insert(legacyAttempt)
            var paused = FocusCountdown(plan: legacy.focusPlan)
            paused.start(at: 0)
            _ = paused.advance(to: 20)
            paused.pause()
            let recovery = try container.mainContext.fetch(FetchDescriptor<TimerRecovery>())[0]
            recovery.taskID = legacy.uuid
            recovery.attemptID = legacyAttempt.uuid
            recovery.state = try JSONEncoder().encode(paused)
            try container.mainContext.save()
            let restored = PomodoroController(container: container, runClock: false)
            restored.start(now: 100)
            restored.cancelCurrent(now: 110)
            let mixed = try await AnalyticsReader(modelContainer: container).load()
            check("resuming a legacy attempt retains its residual once alongside new intervals",
                  abs(mixed.days.values.reduce(0) { $0 + $1.focus } - 80) < 0.001)

            let tomorrow = calendar.date(byAdding: .day, value: 4, to: .now)!
            model.openDailyList(now: tomorrow, animate: false)
            check("reopening after several days creates no empty intermediate lists",
                  try container.mainContext.fetchCount(FetchDescriptor<DailyList>()) == 3)
            check("day rollover safely stops the prior timer", timer.countdown == nil)
        } catch {
            check("daily history fixtures execute successfully: \(error)", false)
        }
    }
}

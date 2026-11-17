import Foundation
import SwiftData
import FocusNoteKit

/// Sample data for snapshots: APP_SEED=1 with APP_STORE in /tmp fills an empty
/// store with realistic items (short and long titles, starred and not).
/// Replace these with your app's own types. Seed only what a person can
/// create in the app, or the snapshots show features no one can use.
@MainActor
enum SeedData {
    static func insertIfRequested(into model: AppModel) {
        guard ProcessInfo.processInfo.environment["APP_SEED"] == "1" else { return }
        guard Store.isOverridden else {
            print("APP_SEED ignored: APP_STORE must be a file in /tmp")
            return
        }
        let context = model.container.mainContext
        guard ((try? context.fetchCount(FetchDescriptor<Item>())) ?? 0) == 0 else { return }
        let samples: [(String, Int)] = [
            ("Write project proposal", 5),
            ("Review research and collect ideas for the next chapter", 3),
            ("Read a chapter", 1),
        ]
        for (index, sample) in samples.enumerated() {
            let item = Item(title: sample.0)
            item.plannedSessions = sample.1
            if index == 0 {
                item.focusMinutes = 40
                item.shortBreakMinutes = 10
                item.longBreakMinutes = 20
            }
            item.isCompleted = index == samples.count - 1
            item.createdAt = Date.now.addingTimeInterval(Double(-index) * 3_600)
            context.insert(item)
        }
        let note = Item(title: "Bring the charger tomorrow", isReminder: true)
        context.insert(note)
        seedHistory(context: context)
        try? context.save()
    }

    private static func seedHistory(context: ModelContext) {
        let calendar = FocusDayKey.calendar()
        for offset in 0..<20 {
            let date = calendar.date(byAdding: .day, value: -offset, to: .now)!
            let key = FocusDayKey.key(date)
            let item = Item(title: offset == 0 ? "Write and review notes" : "Deep work · \(date.formatted(.dateTime.month().day()))")
            item.dayKey = key
            item.listDate = date
            item.plannedSessions = 8
            let totalMinutes = [130, 160, 95, 180, 120, 70, 145][offset % 7]
            item.completedPomodoros = totalMinutes / 25
            item.isCompleted = offset > 0 && offset.isMultiple(of: 3)
            context.insert(item)
            let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date)!
            var minutes = totalMinutes
            var index = 0
            while minutes > 0 {
                let duration = min(25, minutes)
                let began = start.addingTimeInterval(Double(index * 35 * 60))
                let attempt = FocusAttempt(taskID: item.uuid, phase: "focus", plannedSeconds: 1_500)
                attempt.startedAt = began
                attempt.endedAt = began.addingTimeInterval(Double(duration * 60))
                attempt.activeSeconds = Double(duration * 60)
                attempt.outcome = duration == 25 ? "completed" : "cancelled"
                attempt.intervalTracking = true
                context.insert(attempt)
                let interval = FocusInterval(attempt: attempt, date: began)
                interval.end = attempt.endedAt!
                interval.activeSeconds = attempt.activeSeconds
                context.insert(interval)
                minutes -= duration
                index += 1
            }
            if offset > 0 {
                let note = Item(title: "Follow up on reading notes", isReminder: true)
                note.listDate = date
                note.dayKey = key
                context.insert(note)
            }
        }
    }
}

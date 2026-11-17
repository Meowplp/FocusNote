import Foundation
import SwiftData
import FocusNoteKit

@Model
final class DailyList {
    var key: String = ""
    var date: Date = Date.now
    var timeZoneID: String = TimeZone.current.identifier
    var timeZoneInferred: Bool = false
    var archivedAt: Date?
    /// Frozen on archive; live days derive their plan from their current tasks.
    var plannedSeconds: Double = 0
    init(key: String, date: Date) { self.key = key; self.date = date }
}

@Model
final class DailyListState {
    var activeKey: String = ""
    init() {}
}

@Model
final class FocusInterval {
    var uuid: UUID = UUID()
    var attemptID: UUID = UUID()
    var taskID: UUID = UUID()
    var phase: String = "focus"
    var start: Date = Date.now
    var end: Date = Date.now
    var activeSeconds: Double = 0
    var approximate: Bool = false
    init(attempt: FocusAttempt, date: Date) {
        attemptID = attempt.uuid
        taskID = attempt.taskID
        phase = attempt.phase
        start = date
        end = date
    }
}

/// One row per uninterrupted running interval, not one row per display tick.
final class FocusActivityRecorder {
    private let context: ModelContext
    private var interval: FocusInterval?
    private var baseline: Double = 0
    init(context: ModelContext) { self.context = context }

    func begin(attempt: FocusAttempt, elapsed: Double, date: Date = .now) {
        guard interval == nil else { return }
        attempt.intervalTracking = true
        baseline = elapsed
        let interval = FocusInterval(attempt: attempt, date: date)
        context.insert(interval)
        self.interval = interval
    }

    func checkpoint(elapsed: Double, running: Bool, date: Date = .now) {
        guard let interval else { return }
        interval.activeSeconds = max(0, elapsed - baseline)
        interval.end = max(interval.start, date)
        if abs(interval.end.timeIntervalSince(interval.start) - interval.activeSeconds) > 2 {
            interval.approximate = true
        }
        if !running { self.interval = nil }
    }
}

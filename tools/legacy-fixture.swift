// Synthetic pre-daily-list schema. No user data or private Git history needed.
import Foundation
import SwiftData

@Model final class Item {
    var title: String
    var notes: String = ""
    var isStarred: Bool = false
    var createdAt: Date = Date.now
    var uuid: UUID = UUID()
    var plannedSessions: Int = 4
    var completedPomodoros: Int = 0
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 20
    var isCompleted: Bool = false
    var isReminder: Bool = false
    var isTrashed: Bool = false
    var listDate: Date = Date.now
    init(title: String) { self.title = title }
}

@Model final class FocusAttempt {
    var uuid: UUID = UUID()
    var taskID: UUID
    var phase: String
    var plannedSeconds: Double
    var activeSeconds: Double = 0
    var startedAt: Date = Date.now
    var endedAt: Date?
    var outcome: String = "active"
    init(taskID: UUID, phase: String, plannedSeconds: Double) {
        self.taskID = taskID
        self.phase = phase
        self.plannedSeconds = plannedSeconds
    }
}

@Model final class TimerRecovery {
    var taskID: UUID?
    var attemptID: UUID?
    var state: Data?
    init() {}
}

@Model final class TimerPreferences {
    var startTaskAutomatically: Bool = false
    var startBreaksAutomatically: Bool = false
    var startNextFocusAutomatically: Bool = false
    var breakAfterTaskCompletion: Bool = true
    var keepOnTop: Bool = true
    var soundsEnabled: Bool = true
    var automaticModeMigrated: Bool = false
    init() {}
}

@main struct LegacyFixture {
    @MainActor static func main() throws {
        let path = CommandLine.arguments[1]
        let container = try ModelContainer(
            for: Item.self, FocusAttempt.self, TimerRecovery.self, TimerPreferences.self,
            configurations: ModelConfiguration(url: URL(fileURLWithPath: path)))
        let item = Item(title: "Synthetic legacy task")
        item.listDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let attempt = FocusAttempt(taskID: item.uuid, phase: "focus", plannedSeconds: 1500)
        attempt.activeSeconds = 1500
        attempt.outcome = "completed"
        attempt.endedAt = .now
        container.mainContext.insert(item)
        container.mainContext.insert(attempt)
        try container.mainContext.save()
    }
}

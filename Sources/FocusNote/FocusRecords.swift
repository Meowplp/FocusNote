import Foundation
import SwiftData

@Model
final class FocusAttempt {
    var uuid: UUID = UUID()
    var taskID: UUID
    var phase: String
    var plannedSeconds: Double
    var activeSeconds: Double = 0
    var startedAt: Date = Date.now
    var endedAt: Date?
    var outcome: String = "active"
    var intervalTracking: Bool = false

    init(taskID: UUID, phase: String, plannedSeconds: Double) {
        self.taskID = taskID
        self.phase = phase
        self.plannedSeconds = plannedSeconds
    }
}

@Model
final class TimerRecovery {
    var taskID: UUID?
    var attemptID: UUID?
    var state: Data?
    init() {}
}

@Model
final class TimerPreferences {
    var startTaskAutomatically: Bool = false
    var startBreaksAutomatically: Bool = false
    var startNextFocusAutomatically: Bool = false
    var breakAfterTaskCompletion: Bool = true
    var keepOnTop: Bool = true
    var soundsEnabled: Bool = true
    var automaticModeMigrated: Bool = false
    init() {}
}

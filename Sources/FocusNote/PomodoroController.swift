import AppKit
import FocusNoteKit
import SwiftData

@Observable
final class PomodoroController: NSObject {
    let container: ModelContainer
    let preferences: TimerPreferences
    private(set) var countdown: FocusCountdown?
    private(set) var taskID: UUID?
    private var selectedTask: Item?
    private(set) var completionID: UUID?
    private(set) var completionConfirmed = false
    @ObservationIgnored var automaticallyDismissCompletion = true
    @ObservationIgnored private var completionTask: Task<Void, Never>?
    var message: String?
    var error: String?
    @ObservationIgnored weak var panel: NSPanel?
    @ObservationIgnored weak var mainWindow: NSWindow?
    @ObservationIgnored var revealList: (() -> Void)?
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var clockEnabled: Bool
    @ObservationIgnored private var timingActivity: NSObjectProtocol?
    @ObservationIgnored private let recovery: TimerRecovery
    @ObservationIgnored private var attempt: FocusAttempt?
    @ObservationIgnored private var lastCheckpoint: TimeInterval = 0
    @ObservationIgnored var soundHandler: ((PhaseSoundCue) -> Void)?
    @ObservationIgnored private let soundPlayer = PhaseSoundPlayer()
    @ObservationIgnored private let activityRecorder: FocusActivityRecorder

    var automaticCycleEnabled: Bool {
        preferences.startTaskAutomatically && preferences.startBreaksAutomatically && preferences.startNextFocusAutomatically
    }

    var clockDiagnostics: (scheduled: Bool, activity: Bool) {
        (ticker?.isValid == true, timingActivity != nil)
    }

    var task: Item? {
        guard let selectedTask, !selectedTask.isTrashed else { return nil }
        return selectedTask
    }

    init(container: ModelContainer, runClock: Bool = true) {
        self.container = container
        clockEnabled = runClock
        let context = container.mainContext
        activityRecorder = FocusActivityRecorder(context: context)
        preferences = (try? context.fetch(FetchDescriptor<TimerPreferences>()).first) ?? TimerPreferences()
        recovery = (try? context.fetch(FetchDescriptor<TimerRecovery>()).first) ?? TimerRecovery()
        super.init()
        if preferences.modelContext == nil { context.insert(preferences) }
        if recovery.modelContext == nil { context.insert(recovery) }
        if !preferences.automaticModeMigrated {
            let automatic = automaticCycleEnabled
            preferences.startTaskAutomatically = automatic
            preferences.startBreaksAutomatically = automatic
            preferences.startNextFocusAutomatically = automatic
            preferences.automaticModeMigrated = true
        }
        restore()
        reconcileCompletedTasks()
        if runClock {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        }
    }

    func completedCount(for id: UUID) -> Int {
        let predicate = #Predicate<FocusAttempt> {
            $0.taskID == id && $0.phase == "focus" && $0.outcome == "completed"
        }
        return (try? container.mainContext.fetchCount(FetchDescriptor(predicate: predicate))) ?? 0
    }

    /// Apply the completion rule to existing history without replaying breaks.
    private func reconcileCompletedTasks() {
        let predicate = #Predicate<FocusAttempt> { $0.phase == "focus" && $0.outcome == "completed" }
        let records = (try? container.mainContext.fetch(FetchDescriptor(predicate: predicate))) ?? []
        let counts = Dictionary(grouping: records, by: \.taskID).mapValues(\.count)
        let items = (try? container.mainContext.fetch(FetchDescriptor<Item>())) ?? []
        var changed = false
        for item in items {
            let completed = item.isReminder ? 0 : counts[item.uuid, default: 0]
            if item.completedPomodoros != completed {
                item.completedPomodoros = completed
                changed = true
            }
            guard !item.isReminder && !item.isTrashed && !item.isCompleted && item.plannedSessions > 0 else { continue }
            // Preserve an in-flight focus whose target was edited; it will
            // evaluate completion at its own natural end.
            if item.uuid == taskID && countdown?.phase == .focus { continue }
            if completed >= item.plannedSessions {
                item.isCompleted = true
                changed = true
            }
        }
        if changed { _ = persist() }
    }

    func openTask(_ item: Item, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard !item.isReminder && !item.isTrashed && !item.isCompleted else { return }
        if taskID == item.uuid, let countdown {
            if (countdown.status == .ready || countdown.status == .paused) && preferences.startTaskAutomatically {
                start(now: now)
            }
            return
        }
        cancelCurrent(now: now)
        taskID = item.uuid
        selectedTask = item
        countdown = FocusCountdown(plan: item.focusPlan, completedSessions: completedCount(for: item.uuid))
        message = nil
        if persist(), preferences.startTaskAutomatically { start(now: now) }
    }

    func start(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard var clock = countdown, let taskID,
              clock.status == .ready || clock.status == .paused else { return }
        guard let task, !task.isReminder else { return }
        if clock.phase == .focus && task.isCompleted { return }
        let isNewAttempt = attempt == nil
        if isNewAttempt {
            let record = FocusAttempt(taskID: taskID, phase: clock.phase.rawValue, plannedSeconds: clock.duration)
            container.mainContext.insert(record)
            attempt = record
        }
        clock.start(at: now)
        countdown = clock
        if let attempt { activityRecorder.begin(attempt: attempt, elapsed: clock.elapsed) }
        message = nil
        if !persist() { countdown?.pause() }
        else if isNewAttempt { playCue(for: clock.phase) }
        synchronizeClock()
    }

    func tick(now: TimeInterval = ProcessInfo.processInfo.systemUptime, allowAutomaticStart: Bool = true,
              publishFractional: Bool = true) {
        let measuredStart = TimerPerformanceProbe.requested ? ProcessInfo.processInfo.systemUptime : 0
        defer {
            synchronizeClock()
            if TimerPerformanceProbe.requested {
                TimerPerformanceProbe.recordTick(ProcessInfo.processInfo.systemUptime - measuredStart)
            }
        }
        guard var clock = countdown, clock.status == .running else { return }
        let previousSeconds = ceil(clock.remaining)
        let completed = clock.advance(to: now)
        if publishFractional || completed != nil || ceil(clock.remaining) != previousSeconds {
            countdown = clock
        }
        if let completed {
            if let attempt, attempt.outcome == "active" {
                attempt.activeSeconds = attempt.plannedSeconds
                attempt.outcome = "completed"
                attempt.endedAt = .now
                activityRecorder.checkpoint(elapsed: attempt.plannedSeconds, running: false)
            }
            attempt = nil
            // Complete the task in the same transaction as its final focus
            // record. Do not route through manual completion, which can cancel
            // the just-prepared long break and create a second break.
            if completed == .focus, let task, !task.isReminder {
                task.completedPomodoros = clock.completedSessions
                if clock.completedSessions >= clock.plan.sessions { task.isCompleted = true }
            }
            message = completed == .focus ? "Pomodoro complete" : "Break complete"
            let saved = persist()
            if saved { playCue(for: completed) }
            if saved && completed == .longBreak && clock.phase == .finished {
                beginCompletion()
            }
            if saved && allowAutomaticStart {
                let isBreak = clock.phase == .shortBreak || clock.phase == .longBreak
                if (isBreak && preferences.startBreaksAutomatically)
                    || (clock.phase == .focus && preferences.startNextFocusAutomatically) {
                    start(now: now)
                }
            }
        } else if now - lastCheckpoint >= 5 {
            countdown = clock
            lastCheckpoint = now
            if !persist() { countdown?.pause() }
        }
    }

    func pause(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        tick(now: now, allowAutomaticStart: false)
        countdown?.pause()
        _ = persist()
        synchronizeClock()
    }

    func reset(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        tick(now: now, allowAutomaticStart: false)
        cancelCompletion()
        cancelAttempt()
        countdown?.reset()
        message = "Session reset; completed Pomodoros kept"
        _ = persist()
        synchronizeClock()
    }

    func skipBreak(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard countdown?.phase == .shortBreak || countdown?.phase == .longBreak else { return }
        tick(now: now, allowAutomaticStart: false)
        cancelAttempt()
        countdown?.skipBreak()
        message = "Break skipped"
        if persist() {
            if countdown?.phase == .finished { beginCompletion() }
            else if countdown?.phase == .focus, preferences.startNextFocusAutomatically { start(now: now) }
        }
        synchronizeClock()
    }

    func cancelCurrent(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        tick(now: now, allowAutomaticStart: false)
        cancelCompletion()
        cancelAttempt()
        countdown = nil
        taskID = nil
        selectedTask = nil
        _ = persist()
        synchronizeClock()
    }

    func taskCompleted(_ item: Item) {
        guard taskID == item.uuid else { return }
        if countdown?.phase == .finished { return }
        if countdown?.phase == .longBreak {
            countdown?.finishAfterBreak()
            _ = persist()
            return
        }
        cancelCurrent()
        guard preferences.breakAfterTaskCompletion else { return }
        taskID = item.uuid
        selectedTask = item
        countdown = FocusCountdown(plan: item.focusPlan, completedSessions: completedCount(for: item.uuid), taskBreak: true)
        message = "Task complete"
        if persist(), preferences.startBreaksAutomatically { start() }
    }

    func planChanged(_ item: Item) {
        guard !item.isReminder && taskID == item.uuid else { return }
        countdown?.updatePlan(item.focusPlan)
        _ = persist()
    }

    func savePreferences() {
        if !preferences.soundsEnabled { soundPlayer.stop() }
        panel?.level = preferences.keepOnTop ? .floating : .normal
        _ = persist()
    }

    func setAutomaticCycle(_ enabled: Bool, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        preferences.startTaskAutomatically = enabled
        preferences.startBreaksAutomatically = enabled
        preferences.startNextFocusAutomatically = enabled
        savePreferences()
        if enabled && countdown?.status == .ready { start(now: now) }
    }

    func previewSound(_ cue: PhaseSoundCue) {
        if !Store.isOverridden { soundPlayer.enqueue(cue) }
    }

    private func playCue(for phase: FocusCountdown.Phase) {
        guard preferences.soundsEnabled && phase != .finished else { return }
        let cue: PhaseSoundCue = phase == .focus ? .work : .rest
        if let soundHandler { soundHandler(cue) }
        else if !Store.isOverridden { soundPlayer.enqueue(cue) }
    }

    func stopClock() {
        cancelCompletion()
        clockEnabled = false
        ticker?.invalidate()
        ticker = nil
        endTimingActivity()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func backToList() {
        revealList?()
        if mainWindow?.isMiniaturized == true { mainWindow?.deminiaturize(nil) }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func retrySave() {
        if persist(), countdown?.phase == .finished { beginCompletion() }
    }

    private func beginCompletion() {
        guard completionID == nil, countdown?.phase == .finished else { return }
        let id = UUID()
        completionID = id
        completionConfirmed = false
        guard automaticallyDismissCompletion else {
            completionConfirmed = true
            return
        }
        completionTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(220))
                guard let self, self.completionID == id else { return }
                self.completionConfirmed = true
                try await Task.sleep(for: .milliseconds(1_000))
                self.finishCompletion(id: id)
            } catch { /* A new task or reset cancels the old celebration. */ }
        }
    }

    func finishCompletion(id: UUID) {
        guard completionID == id, countdown?.phase == .finished else { return }
        // Keep the finished state until clearing recovery has saved successfully.
        let previous = countdown
        let previousTaskID = taskID
        countdown = nil
        taskID = nil
        guard persist() else {
            countdown = previous
            taskID = previousTaskID
            cancelCompletion()
            return
        }
        selectedTask = nil
        cancelCompletion()
        panel?.orderOut(nil)
        backToList()
    }

    private func cancelCompletion() {
        completionTask?.cancel()
        completionTask = nil
        completionID = nil
        completionConfirmed = false
    }

    /// Checkpoint phase, attempt outcome, and elapsed time in one database save.
    @discardableResult
    func persist() -> Bool {
        let measuredStart = TimerPerformanceProbe.requested ? ProcessInfo.processInfo.systemUptime : 0
        defer {
            if TimerPerformanceProbe.requested {
                TimerPerformanceProbe.recordSave(ProcessInfo.processInfo.systemUptime - measuredStart)
            }
        }
        attempt?.activeSeconds = countdown?.elapsed ?? 0
        if attempt != nil {
            activityRecorder.checkpoint(elapsed: countdown?.elapsed ?? 0, running: countdown?.status == .running)
        }
        recovery.taskID = taskID
        recovery.attemptID = attempt?.uuid
        recovery.state = countdown.flatMap { try? JSONEncoder().encode($0) }
        do {
            try container.mainContext.save()
            NotificationCenter.default.post(name: .focusRecordsChanged, object: nil)
            error = nil
            return true
        } catch {
            activityRecorder.checkpoint(elapsed: countdown?.elapsed ?? 0, running: false)
            countdown?.pause()
            synchronizeClock()
            self.error = "Unable to save timer progress. Retry to save."
            return false
        }
    }

    private func cancelAttempt() {
        guard let attempt else { return }
        attempt.activeSeconds = countdown?.elapsed ?? attempt.activeSeconds
        activityRecorder.checkpoint(elapsed: attempt.activeSeconds, running: false)
        attempt.outcome = "cancelled"
        attempt.endedAt = .now
        self.attempt = nil
    }

    private func restore() {
        guard let id = recovery.taskID, let data = recovery.state,
              var restored = try? JSONDecoder().decode(FocusCountdown.self, from: data) else { return }
        taskID = id
        let predicate = #Predicate<Item> { $0.uuid == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        selectedTask = try? container.mainContext.fetch(descriptor).first
        restored.restorePaused()
        countdown = restored
        if let attemptID = recovery.attemptID {
            attempt = (try? container.mainContext.fetch(FetchDescriptor<FocusAttempt>()))?.first { $0.uuid == attemptID && $0.outcome == "active" }
        }
        guard task != nil else { cancelCurrent(); return }
        message = restored.status == .paused ? "Session restored paused" : "Timer restored"
    }

    @objc private func willSleep(_ notification: Notification) {
        pause()
        message = "Paused while your Mac sleeps"
    }

    private func synchronizeClock() {
        guard clockEnabled, countdown?.status == .running else {
            ticker?.invalidate()
            ticker = nil
            endTimingActivity()
            return
        }
        if timingActivity == nil {
            // Suppress App Nap during active work/rest, but permit normal Mac
            // sleep. willSleep still pauses/checkpoints the session.
            timingActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep, reason: "Run the Pomodoro countdown")
        }
        guard ticker == nil,
              let delay = countdown?.nextDisplayRefreshDelay(at: ProcessInfo.processInfo.systemUptime) else { return }
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.ticker = nil
                self.tick(publishFractional: false)
            }
        }
        timer.tolerance = 0.002
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .modalPanel)
        ticker = timer
    }

    private func endTimingActivity() {
        if let timingActivity {
            ProcessInfo.processInfo.endActivity(timingActivity)
            self.timingActivity = nil
        }
    }
}

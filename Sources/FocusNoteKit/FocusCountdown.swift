import Foundation

/// Pure countdown state. Callers inject monotonic seconds, so tests never wait.
/// One tick can complete only one phase; late callbacks never invent sessions.
public struct FocusCountdown: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable {
        case focus, shortBreak, longBreak, finished
    }
    public enum Status: String, Codable, Sendable {
        case ready, running, paused, finished
    }
    public private(set) var plan: FocusPlan
    public private(set) var completedSessions: Int
    public private(set) var phase: Phase
    public private(set) var status: Status
    public private(set) var elapsed: TimeInterval = 0
    private var lastTick: TimeInterval?
    private var lockedDuration: TimeInterval?
    private var stopAfterBreak: Bool = false

    public init(plan: FocusPlan, completedSessions: Int = 0, taskBreak: Bool = false) {
        self.plan = plan
        self.completedSessions = max(0, completedSessions)
        phase = taskBreak ? .longBreak : (completedSessions >= plan.sessions ? .finished : .focus)
        status = phase == .finished ? .finished : .ready
        stopAfterBreak = taskBreak
    }

    public var duration: TimeInterval {
        if let lockedDuration { return lockedDuration }
        let minutes = switch phase {
        case .focus: plan.focusMinutes
        case .shortBreak: plan.shortBreakMinutes
        case .longBreak: plan.longBreakMinutes
        case .finished: 0
        }
        return Double(minutes * 60)
    }

    public var remaining: TimeInterval { max(0, duration - elapsed) }

    public func nextDisplayRefreshDelay(at now: TimeInterval) -> TimeInterval? {
        guard status == .running else { return nil }
        var projected = self
        if projected.advance(to: now) != nil { return 0.005 }
        return CountdownRefreshSchedule.delay(remaining: projected.remaining)
    }

    public mutating func start(at now: TimeInterval) {
        guard status == .ready || status == .paused else { return }
        lockedDuration = duration
        status = .running
        lastTick = now
    }

    /// Returns the phase that finished, once. The next phase is ready, not
    /// running: the controller decides whether to automatically start it.
    @discardableResult
    public mutating func advance(to now: TimeInterval) -> Phase? {
        guard status == .running, let lastTick else { return nil }
        elapsed = min(duration, elapsed + max(0, now - lastTick))
        self.lastTick = max(now, lastTick)
        guard remaining <= 0 else { return nil }
        let completed = phase
        switch phase {
        case .focus:
            completedSessions += 1
            phase = completedSessions >= plan.sessions ? .longBreak : .shortBreak
        case .shortBreak: phase = completedSessions >= plan.sessions ? .longBreak : .focus
        case .longBreak:
            phase = !stopAfterBreak && completedSessions < plan.sessions ? .focus : .finished
        case .finished: phase = .finished
        }
        elapsed = 0
        lockedDuration = nil
        self.lastTick = nil
        status = phase == .finished ? .finished : .ready
        return completed
    }

    /// Advance first in the controller to handle a possible boundary event.
    public mutating func pause() {
        guard status == .running else { return }
        status = .paused
        lastTick = nil
    }

    public mutating func reset() {
        guard phase != .finished else { return }
        elapsed = 0
        lockedDuration = nil
        lastTick = nil
        status = .ready
    }

    public mutating func skipBreak() {
        guard phase == .shortBreak || phase == .longBreak else { return }
        if phase == .longBreak {
            phase = !stopAfterBreak && completedSessions < plan.sessions ? .focus : .finished
        } else {
            phase = completedSessions >= plan.sessions ? .longBreak : .focus
        }
        status = phase == .finished ? .finished : .ready
        elapsed = 0
        lockedDuration = nil
        lastTick = nil
    }

    public mutating func restorePaused() {
        lastTick = nil
        if status == .running { status = .paused }
    }

    public mutating func updatePlan(_ plan: FocusPlan) {
        guard plan.isValid else { return }
        self.plan = plan
        if status == .finished && completedSessions < plan.sessions {
            phase = .focus
            status = .ready
        } else if status == .ready && phase == .focus && completedSessions >= plan.sessions {
            phase = .longBreak
        }
    }

    public mutating func finishAfterBreak() {
        stopAfterBreak = true
    }
}

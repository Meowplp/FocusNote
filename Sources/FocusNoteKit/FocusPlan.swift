/// Per-task settings. Short breaks go between sessions; the long break
/// replaces the short break after the task's final planned Pomodoro.
public struct FocusPlan: Codable, Equatable, Sendable {
    public var sessions: Int
    public var focusMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int

    public init(sessions: Int = 4, focusMinutes: Int = 25, shortBreakMinutes: Int = 5, longBreakMinutes: Int = 20) {
        self.sessions = sessions
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
    }

    public var isValid: Bool {
        (1...100).contains(sessions)
            && [focusMinutes, shortBreakMinutes, longBreakMinutes].allSatisfy { (1...240).contains($0) }
    }
}

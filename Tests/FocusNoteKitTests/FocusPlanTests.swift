import Testing
@testable import FocusNoteKit

@Test("Focus plans validate every duration", arguments: [
    FocusPlan(sessions: 5, focusMinutes: 40, shortBreakMinutes: 10, longBreakMinutes: 20),
    FocusPlan(sessions: 1, focusMinutes: 1, shortBreakMinutes: 1, longBreakMinutes: 1),
    FocusPlan(sessions: 100, focusMinutes: 240, shortBreakMinutes: 240, longBreakMinutes: 240),
])
func acceptsFocusPlan(_ plan: FocusPlan) {
    #expect(plan.isValid)
}

@Test("Focus plans reject invalid counts or durations", arguments: [
    FocusPlan(sessions: 0),
    FocusPlan(sessions: 101),
    FocusPlan(focusMinutes: 0),
    FocusPlan(focusMinutes: 241),
    FocusPlan(shortBreakMinutes: -1),
    FocusPlan(shortBreakMinutes: 241),
    FocusPlan(longBreakMinutes: 0),
    FocusPlan(longBreakMinutes: 241),
])
func rejectsFocusPlan(_ plan: FocusPlan) {
    #expect(!plan.isValid)
}

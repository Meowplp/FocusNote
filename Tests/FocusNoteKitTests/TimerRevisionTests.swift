import Testing
@testable import FocusNoteKit

@Test("Four Pomodoros mean 4 × 25 work, 3 × 5 short breaks, 1 × 20 long break")
func exactFourSessionSequence() {
    var clock = FocusCountdown(plan: FocusPlan(sessions: 4, focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 20))
    var phases: [FocusCountdown.Phase] = []
    var durations: [Double] = []
    var now = 0.0
    for _ in 0..<8 {
        phases.append(clock.phase)
        durations.append(clock.duration)
        clock.start(at: now)
        now += clock.duration
        _ = clock.advance(to: now)
    }
    #expect(phases == [.focus, .shortBreak, .focus, .shortBreak, .focus, .shortBreak, .focus, .longBreak])
    #expect(durations == [1_500, 300, 1_500, 300, 1_500, 300, 1_500, 1_200])
    #expect(now == 135 * 60)
    #expect(clock.completedSessions == 4)
    #expect(clock.phase == .finished)
}

@Test("Lowering the target during a short break cannot start extra focus")
func targetReducedDuringBreak() {
    var clock = FocusCountdown(plan: FocusPlan(sessions: 4, focusMinutes: 1, shortBreakMinutes: 1))
    clock.start(at: 0)
    _ = clock.advance(to: 60)
    clock.start(at: 60)
    clock.updatePlan(FocusPlan(sessions: 1))
    _ = clock.advance(to: 120)
    #expect(clock.phase == .longBreak)
    #expect(clock.completedSessions == 1)
}

@Test("Skipping a short break also respects a reduced target")
func skipWithReducedTarget() {
    var clock = FocusCountdown(plan: FocusPlan(sessions: 4, focusMinutes: 1))
    clock.start(at: 0)
    _ = clock.advance(to: 60)
    clock.updatePlan(FocusPlan(sessions: 1))
    clock.skipBreak()
    #expect(clock.phase == .longBreak)
    #expect(clock.completedSessions == 1)
}

@Test("Timer typography scales down and up with the available size")
func responsiveLayout() {
    let minimum = TimerLayout(width: 160, height: 168)
    let standard = TimerLayout(width: 180, height: 190)
    let expanded = TimerLayout(width: 360, height: 380)
    #expect(minimum.compact && standard.compact && !expanded.compact)
    #expect(minimum.digitSize <= standard.digitSize)
    #expect(standard.digitSize < expanded.digitSize)
    #expect(minimum.digitSize >= 24)
    #expect(expanded.digitSize <= 72)
}

import Foundation
import Testing
@testable import FocusNoteKit

@Test("Five focus sessions get four short breaks then one long break")
func fullTaskSequence() {
    var clock = FocusCountdown(plan: FocusPlan(sessions: 5, focusMinutes: 40, shortBreakMinutes: 10, longBreakMinutes: 20))
    var now = 0.0
    for session in 1...5 {
        #expect(clock.phase == .focus)
        #expect(clock.duration == 2_400)
        clock.start(at: now)
        now += 2_400
        #expect(clock.advance(to: now) == .focus)
        #expect(clock.completedSessions == session)
        #expect(clock.status == .ready)
        #expect(clock.phase == (session == 5 ? .longBreak : .shortBreak))
        #expect(clock.duration == (session == 5 ? 1_200 : 600))
        clock.start(at: now)
        now += clock.duration
        _ = clock.advance(to: now)
    }
    #expect(clock.phase == .finished)
    #expect(clock.status == .finished)
    #expect(clock.completedSessions == 5)
}

@Test("Pause excludes paused time and resume uses monotonic elapsed time")
func pauseResume() {
    var clock = FocusCountdown(plan: FocusPlan())
    clock.start(at: 100)
    #expect(clock.advance(to: 137.5) == nil)
    #expect(clock.remaining == 1_462.5)
    clock.pause()
    #expect(clock.advance(to: 10_000) == nil)
    #expect(clock.remaining == 1_462.5)
    clock.start(at: 20_000)
    _ = clock.advance(to: 20_010)
    #expect(clock.remaining == 1_452.5)
}

@Test("Late or repeated callbacks cannot fabricate extra sessions")
func delayedCallbacks() {
    var clock = FocusCountdown(plan: FocusPlan())
    clock.start(at: 0)
    #expect(clock.advance(to: 1_000_000) == .focus)
    #expect(clock.completedSessions == 1)
    #expect(clock.phase == .shortBreak)
    #expect(clock.elapsed == 0)
    #expect(clock.advance(to: 1_000_000) == nil)
    #expect(clock.completedSessions == 1)
}

@Test("Reset and skipped breaks preserve completed focus")
func resetAndSkip() {
    var clock = FocusCountdown(plan: FocusPlan(sessions: 2, focusMinutes: 1, shortBreakMinutes: 1, longBreakMinutes: 2))
    clock.start(at: 0)
    _ = clock.advance(to: 60)
    clock.skipBreak()
    #expect(clock.phase == .focus)
    clock.start(at: 60)
    _ = clock.advance(to: 80)
    clock.reset()
    #expect(clock.remaining == 60)
    #expect(clock.status == .ready)
    #expect(clock.completedSessions == 1)
    clock.start(at: 100)
    _ = clock.advance(to: 160)
    #expect(clock.phase == .longBreak)
    clock.skipBreak()
    #expect(clock.phase == .finished)
    #expect(clock.completedSessions == 2)
}

@Test("Restoring an encoded running session never counts offline time")
func recovery() throws {
    var clock = FocusCountdown(plan: FocusPlan())
    clock.start(at: 0)
    _ = clock.advance(to: 30)
    let data = try JSONEncoder().encode(clock)
    var restored = try JSONDecoder().decode(FocusCountdown.self, from: data)
    restored.restorePaused()
    _ = restored.advance(to: 999_999)
    #expect(restored.status == .paused)
    #expect(restored.remaining == 1_470)
    #expect(restored.completedSessions == 0)
}

@Test("An already fulfilled target cannot earn another focus by reopening")
func alreadyComplete() {
    var clock = FocusCountdown(plan: FocusPlan(sessions: 2), completedSessions: 2)
    clock.start(at: 0)
    #expect(clock.advance(to: 99_999) == nil)
    #expect(clock.status == .finished)
    #expect(clock.completedSessions == 2)
}

@Test("A backwards timestamp never adds time or earns completion")
func backwardsTimestamp() {
    var clock = FocusCountdown(plan: FocusPlan())
    clock.start(at: 100)
    _ = clock.advance(to: 120)
    _ = clock.advance(to: 110)
    _ = clock.advance(to: 125)
    #expect(clock.elapsed == 25)
}

@Test("Plan edits preserve active duration and update subsequent phases")
func editsDuringFocus() {
    var clock = FocusCountdown(plan: FocusPlan(sessions: 2, focusMinutes: 1, shortBreakMinutes: 1))
    clock.start(at: 0)
    _ = clock.advance(to: 20)
    clock.updatePlan(FocusPlan(sessions: 2, focusMinutes: 40, shortBreakMinutes: 10, longBreakMinutes: 20))
    #expect(clock.remaining == 40)
    _ = clock.advance(to: 60)
    #expect(clock.phase == .shortBreak)
    #expect(clock.duration == 600)
    clock.skipBreak()
    #expect(clock.duration == 2_400)
}

@Test("Extending a target during a long break allows future focus")
func extendingTarget() {
    var clock = FocusCountdown(plan: FocusPlan(sessions: 1, focusMinutes: 1))
    clock.start(at: 0)
    _ = clock.advance(to: 60)
    clock.start(at: 60)
    clock.updatePlan(FocusPlan(sessions: 2))
    _ = clock.advance(to: 1_260)
    #expect(clock.phase == .focus)
    #expect(clock.completedSessions == 1)
}

@Test("Completing a task early ends after its long break even below target")
func earlyCompletion() {
    var clock = FocusCountdown(plan: FocusPlan(sessions: 5, longBreakMinutes: 20), taskBreak: true)
    clock.start(at: 0)
    _ = clock.advance(to: 1_200)
    #expect(clock.phase == .finished)
    #expect(clock.completedSessions == 0)
}

import Foundation
import Testing
@testable import FocusNoteKit

@Test("Display refresh covers every second despite bounded callback jitter")
func displayRefreshCoversEverySecond() {
    var clock = FocusCountdown(plan: FocusPlan())
    clock.start(at: 0)
    var now = 0.0
    var lastSeconds = Int(ceil(clock.remaining))
    var skipped = 0
    for index in 0..<120 {
        // Slight early/late relative phase, not a blocked UI thread.
        let jitter = index.isMultiple(of: 2) ? -0.04 : 0.08
        now += max(0.001, CountdownRefreshSchedule.delay(remaining: clock.remaining) + jitter)
        _ = clock.advance(to: now)
        let seconds = Int(ceil(clock.remaining))
        skipped += max(0, lastSeconds - seconds - 1)
        lastSeconds = seconds
    }
    #expect(skipped == 0)
    #expect(abs(clock.elapsed - now) < 0.000_001)
}

@Test("Refresh deadlines align with the current remaining time")
func alignsWithBoundary() {
    #expect(abs(CountdownRefreshSchedule.delay(remaining: 60) - 1.005) < 0.000_001)
    #expect(abs(CountdownRefreshSchedule.delay(remaining: 59.25) - 0.255) < 0.000_001)
    #expect(CountdownRefreshSchedule.delay(remaining: 0) == 0.005)
}

@Test("Inactive states never request a display wake-up")
func inactiveRefresh() {
    var clock = FocusCountdown(plan: FocusPlan())
    #expect(clock.nextDisplayRefreshDelay(at: 0) == nil)
    clock.start(at: 0)
    #expect(abs((clock.nextDisplayRefreshDelay(at: 0.75) ?? 0) - 0.255) < 0.000_001)
    clock.pause()
    #expect(clock.nextDisplayRefreshDelay(at: 100) == nil)
}

@Test("A genuinely delayed callback catches up instead of slowing the clock")
func delayedRefreshRemainsAccurate() {
    var clock = FocusCountdown(plan: FocusPlan(focusMinutes: 1))
    clock.start(at: 0)
    _ = clock.advance(to: 7.25)
    #expect(clock.remaining == 52.75)
    #expect(clock.completedSessions == 0)
    #expect(clock.nextDisplayRefreshDelay(at: 100) == 0.005)
    // Merely asking for a deadline must not award a completed session.
    #expect(clock.completedSessions == 0)
}

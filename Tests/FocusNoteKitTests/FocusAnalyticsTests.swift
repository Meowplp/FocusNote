import Foundation
import Testing
@testable import FocusNoteKit

private let utc = TimeZone(secondsFromGMT: 0)!
private let taskID = UUID()
private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

@Test("Focus intervals split across midnight and hourly boundaries")
func analyticsMidnight() {
    let sample = FocusSample(taskID: taskID, start: date("2026-11-16T23:50:00Z"),
                             end: date("2026-11-17T00:15:00Z"), seconds: 1_500)
    let report = FocusAnalytics(samples: [sample], plans: [], completions: [], timeZone: utc)
    #expect(report.days["2026-11-16"]?.focus == 600)
    #expect(report.days["2026-11-17"]?.focus == 900)
    #expect(report.days["2026-11-16"]?.hours[23] == 600)
    #expect(report.days["2026-11-17"]?.hours[0] == 900)
    #expect(report.days.values.reduce(0) { $0 + $1.focus } == 1_500)
}

@Test("Paused gaps never become focus and breaks remain separate")
func analyticsPauseAndBreaks() {
    let samples = [
        FocusSample(taskID: taskID, start: date("2026-11-17T09:00:00Z"), end: date("2026-11-17T09:10:00Z"), seconds: 600),
        FocusSample(taskID: taskID, start: date("2026-11-17T10:00:00Z"), end: date("2026-11-17T10:05:00Z"), seconds: 300),
        FocusSample(taskID: taskID, start: date("2026-11-17T10:05:00Z"), end: date("2026-11-17T10:10:00Z"), seconds: 300, isBreak: true)
    ]
    let report = FocusAnalytics(samples: samples, plans: [.init(key: "2026-11-17", seconds: 1_200)],
                                completions: [], partialSamples: [samples[1]], timeZone: utc)
    let day = report.days["2026-11-17"]!
    #expect(day.focus == 900)
    #expect(day.breaks == 300)
    #expect(day.partial == 300)
    #expect(day.pomodoros == 0)
    #expect(day.planned == 1_200)
    #expect(day.tasks[taskID] == 900)
}

@Test("Streaks include weekends, preserve yesterday until today ends, and keep best")
func analyticsStreaks() {
    let samples = (0..<20).map { index in
        let start = date("2026-10-28T12:00:00Z").addingTimeInterval(Double(index * 86_400))
        return FocusSample(taskID: taskID, start: start, end: start.addingTimeInterval(600), seconds: 600)
    }
    let report = FocusAnalytics(samples: samples, plans: [], completions: [], timeZone: utc)
    let streak = report.streaks(today: date("2026-11-17T09:00:00Z"))
    #expect(streak.current == 20)
    #expect(streak.best == 20)
    #expect(!streak.todayCounted)
    #expect(report.streaks(today: date("2026-11-18T09:00:00Z")).current == 0)
    #expect(report.streaks(today: date("2026-11-16T23:59:59Z")).todayCounted)
}

@Test("Short focus and future activity cannot inflate the current streak")
func analyticsStreakThreshold() {
    let report = FocusAnalytics(samples: [
        .init(taskID: taskID, start: date("2026-11-17T09:00:00Z"), end: date("2026-11-17T09:09:59Z"), seconds: 599),
        .init(taskID: taskID, start: date("2026-11-18T09:00:00Z"), end: date("2026-11-18T09:10:00Z"), seconds: 600)
    ], plans: [], completions: [], timeZone: utc)
    #expect(report.streaks(today: date("2026-11-17T23:00:00Z")).current == 0)
    #expect(report.streaks(today: date("2026-11-17T23:00:00Z")).best == 0)
}

@Test("Legacy totals are preserved without inventing paused hourly activity")
func analyticsLegacy() {
    let report = FocusAnalytics(samples: [
        .init(taskID: taskID, start: date("2026-11-16T23:00:00Z"), end: date("2026-11-17T10:00:00Z"),
              seconds: 900, approximate: true)
    ], plans: [], completions: [.init(date: date("2026-11-17T10:00:00Z"))], timeZone: utc)
    #expect(report.days["2026-11-16"]?.focus == 900)
    #expect(report.days["2026-11-16"]?.approximate == true)
    #expect(report.days["2026-11-17"]?.focus == 0)
    #expect(report.days["2026-11-17"]?.pomodoros == 1)
}

@Test("DST short and long days preserve duration")
func analyticsDaylightSaving() {
    let zone = TimeZone(identifier: "America/Los_Angeles")!
    for (start, end, expected) in [
        ("2026-03-08T08:00:00Z", "2026-03-09T07:00:00Z", 23.0 * 3_600),
        ("2026-11-01T07:00:00Z", "2026-11-02T08:00:00Z", 25.0 * 3_600)
    ] {
        let report = FocusAnalytics(samples: [
            .init(taskID: taskID, start: date(start), end: date(end), seconds: expected)
        ], plans: [], completions: [], timeZone: zone)
        #expect(report.days.count == 1)
        #expect(report.days.values.first?.focus == expected)
        #expect(report.days.values.first?.hours.reduce(0, +) == expected)
    }
}

@Test("Empty periods, zero plans, and exceeding plans retain actual duration")
func analyticsEmptyAndBeyondPlan() {
    let report = FocusAnalytics(samples: [
        .init(taskID: taskID, start: date("2026-11-17T09:00:00Z"), end: date("2026-11-17T10:00:00Z"), seconds: 3_600)
    ], plans: [.init(key: "2026-11-17", seconds: 1_800)], completions: [], timeZone: utc)
    #expect(report.days["2026-11-17"]!.focus / report.days["2026-11-17"]!.planned == 2)
    #expect(report.day(date("2026-11-18T12:00:00Z")).focus == 0)
    #expect(report.day(date("2026-11-18T12:00:00Z")).planned == 0)
}

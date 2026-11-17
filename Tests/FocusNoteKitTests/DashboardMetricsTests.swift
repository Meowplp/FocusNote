import Foundation
import Testing
@testable import FocusNoteKit

@Test("Heatmap bands use strict 50 and 80 percent boundaries",
      arguments: [(0.0, PlanAchievement.belowHalf), (0.5, .belowHalf), (0.5001, .aboveHalf),
                  (0.8, .aboveHalf), (0.8001, .aboveEighty), (1.5, .aboveEighty)])
func heatmapBands(ratio: Double, expected: PlanAchievement) {
    var day = FocusDaySummary(id: "2026-11-17")
    day.planned = 3_600
    day.focus = day.planned * ratio
    #expect(day.planAchievement == expected)
}

@Test("Unplanned work never earns a fabricated heatmap percentage")
func heatmapNoPlan() {
    var day = FocusDaySummary(id: "2026-11-17")
    day.focus = 7_200
    #expect(day.planAchievement == .noPlan)
}

@Test("Week averages compare the same elapsed days and preserve fractional hours")
func weekAverages() {
    let zone = TimeZone(secondsFromGMT: 0)!
    let calendar = FocusDayKey.calendar(timeZone: zone)
    let monday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12))!
    let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
    let wednesday = calendar.date(byAdding: .day, value: 2, to: monday)!
    let task = UUID()
    let data = FocusAnalytics(samples: [
        FocusSample(taskID: task, start: monday, end: monday.addingTimeInterval(7_200), seconds: 7_200),
        FocusSample(taskID: task, start: tuesday, end: tuesday.addingTimeInterval(3_600), seconds: 3_600)
    ], plans: [
        .init(key: "2026-11-16", seconds: 10.5 * 3_600),
        .init(key: "2026-11-17", seconds: 3.5 * 3_600),
        .init(key: "2026-11-18", seconds: 8 * 3_600)
    ], completions: [], timeZone: zone)
    let current = data.week(containing: monday, now: tuesday)
    #expect(current.dates.count == 7)
    #expect(current.elapsedDays == 2)
    #expect(current.averagePlanned == 7 * 3_600)
    #expect(current.averageActual == 1.5 * 3_600)
    #expect(current.days[0].planned / 3_600 == 10.5)
    #expect(current.days[2].planned == 8 * 3_600) // Future plan remains visible, not in average.
    let complete = data.week(containing: monday, now: calendar.date(byAdding: .weekOfYear, value: 1, to: wednesday)!)
    #expect(complete.elapsedDays == 7)
    #expect(complete.averagePlanned == 22.0 * 3_600 / 7)
    #expect(complete.averageActual == 3.0 * 3_600 / 7)
}

@Test("Empty and future weeks have safe zero averages")
func emptyWeekAverages() {
    let data = FocusAnalytics(samples: [], plans: [], completions: [])
    let future = data.calendar.date(byAdding: .weekOfYear, value: 2, to: .now)!
    let week = data.week(containing: future, now: .now)
    #expect(week.elapsedDays == 0)
    #expect(week.averageActual == 0 && week.averagePlanned == 0)
}

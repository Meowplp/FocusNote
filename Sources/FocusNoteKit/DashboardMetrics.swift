import Foundation

public enum PlanAchievement: Sendable, Equatable {
    case noPlan, belowHalf, aboveHalf, aboveEighty
}

extension FocusDaySummary {
    public var planAchievement: PlanAchievement {
        guard planned.isFinite, planned > 0 else { return .noPlan }
        let ratio = focus / planned
        if ratio > 0.8 { return .aboveEighty }
        if ratio > 0.5 { return .aboveHalf }
        return .belowHalf
    }
}

public struct FocusWeekSummary: Sendable {
    public let dates: [Date]
    public let days: [FocusDaySummary]
    public let elapsedDays: Int
    public var averagePlanned: Double {
        elapsedDays == 0 ? 0 : days.prefix(elapsedDays).reduce(0) { $0 + $1.planned } / Double(elapsedDays)
    }
    public var averageActual: Double {
        elapsedDays == 0 ? 0 : days.prefix(elapsedDays).reduce(0) { $0 + $1.focus } / Double(elapsedDays)
    }
}

extension FocusAnalytics {
    public func week(containing date: Date, now: Date) -> FocusWeekSummary {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        let dates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        return FocusWeekSummary(dates: dates, days: dates.map { day($0) },
                                elapsedDays: dates.filter { $0 <= now }.count)
    }
}

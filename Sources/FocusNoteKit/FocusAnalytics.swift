import Foundation

public enum FocusDayKey {
    public static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    public static func key(_ date: Date, calendar: Calendar = calendar()) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func date(_ key: String, calendar: Calendar = calendar()) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}

public struct FocusSample: Sendable {
    public let taskID: UUID
    public let start: Date
    public let end: Date
    public let seconds: Double
    public let isBreak: Bool
    public let approximate: Bool
    public init(taskID: UUID, start: Date, end: Date, seconds: Double, isBreak: Bool = false, approximate: Bool = false) {
        self.taskID = taskID
        self.start = start
        self.end = end
        self.seconds = seconds
        self.isBreak = isBreak
        self.approximate = approximate
    }
}

public struct FocusPlanSample: Sendable {
    public let key: String
    public let seconds: Double
    public init(key: String, seconds: Double) { self.key = key; self.seconds = seconds }
}

public struct FocusCompletion: Sendable {
    public let date: Date
    public init(date: Date) { self.date = date }
}

public struct FocusTaskInfo: Sendable {
    public let id: UUID
    public let title: String
    public let dayKey: String
    public let planned: Double
    public init(id: UUID, title: String, dayKey: String = "", planned: Double = 0) {
        self.id = id; self.title = title; self.dayKey = dayKey; self.planned = planned
    }
}

public struct FocusSessionInfo: Sendable, Identifiable {
    public let id: UUID
    public let taskID: UUID
    public let start: Date
    public let end: Date?
    public let seconds: Double
    public let phase: String
    public let outcome: String
    public init(id: UUID, taskID: UUID, start: Date, end: Date?, seconds: Double, phase: String, outcome: String) {
        self.id = id; self.taskID = taskID; self.start = start; self.end = end
        self.seconds = seconds; self.phase = phase; self.outcome = outcome
    }
}

public struct FocusDaySummary: Sendable, Identifiable {
    public let id: String
    public var focus: Double = 0
    public var planned: Double = 0
    public var breaks: Double = 0
    public var pomodoros: Int = 0
    public var partial: Double = 0
    public var approximate = false
    public var hours: [Double] = Array(repeating: 0, count: 24)
    public var tasks: [UUID: Double] = [:]
    public init(id: String) { self.id = id }
}

public struct FocusAnalytics: Sendable {
    public var days: [String: FocusDaySummary] = [:]
    public var titles: [UUID: String] = [:]
    public var taskInfo: [UUID: FocusTaskInfo] = [:]
    public let sessions: [FocusSessionInfo]
    public let timeZoneID: String

    public init(samples: [FocusSample], plans: [FocusPlanSample], completions: [FocusCompletion],
                tasks: [FocusTaskInfo] = [], partialSamples: [FocusSample] = [],
                sessions: [FocusSessionInfo] = [],
                timeZone: TimeZone = .current) {
        timeZoneID = timeZone.identifier
        self.sessions = sessions
        let calendar = FocusDayKey.calendar(timeZone: timeZone)
        for task in tasks { titles[task.id] = task.title; taskInfo[task.id] = task }
        for plan in plans {
            let key = plan.key
            var day = days[key] ?? FocusDaySummary(id: key)
            day.planned += max(0, plan.seconds)
            days[key] = day
        }
        for sample in samples { distribute(sample, calendar: calendar, partialOnly: false) }
        for sample in partialSamples { distribute(sample, calendar: calendar, partialOnly: true) }
        for completion in completions {
            let key = FocusDayKey.key(completion.date, calendar: calendar)
            var day = days[key] ?? FocusDaySummary(id: key)
            day.pomodoros += 1
            days[key] = day
        }
    }

    private mutating func distribute(_ sample: FocusSample, calendar: Calendar, partialOnly: Bool) {
        guard sample.seconds.isFinite, sample.seconds > 0 else { return }
        // Old attempts have no pause boundaries. Preserve totals, but do not
        // invent precise hourly intervals: attribute to the recorded start.
        if sample.approximate || sample.end <= sample.start {
            add(sample, date: sample.start, seconds: sample.seconds, calendar: calendar, partialOnly: partialOnly)
            return
        }
        let span = sample.end.timeIntervalSince(sample.start)
        var cursor = sample.start
        while cursor < sample.end {
            let boundary = calendar.dateInterval(of: .hour, for: cursor)?.end ?? sample.end
            let end = min(sample.end, boundary)
            guard end > cursor else { break }
            add(sample, date: cursor, seconds: sample.seconds * end.timeIntervalSince(cursor) / span,
                calendar: calendar, partialOnly: partialOnly)
            cursor = end
        }
    }

    private mutating func add(_ sample: FocusSample, date: Date, seconds: Double,
                              calendar: Calendar, partialOnly: Bool) {
        let key = FocusDayKey.key(date, calendar: calendar)
        var day = days[key] ?? FocusDaySummary(id: key)
        if partialOnly {
            day.partial += seconds
        } else if sample.isBreak {
            day.breaks += seconds
        } else {
            day.focus += seconds
            day.hours[calendar.component(.hour, from: date)] += seconds
            day.tasks[sample.taskID, default: 0] += seconds
        }
        day.approximate = day.approximate || sample.approximate
        days[key] = day
    }

    public func day(_ date: Date) -> FocusDaySummary {
        let key = FocusDayKey.key(date, calendar: calendar)
        return days[key] ?? FocusDaySummary(id: key)
    }

    public var calendar: Calendar {
        FocusDayKey.calendar(timeZone: TimeZone(identifier: timeZoneID) ?? .current)
    }

    /// Today has until midnight to qualify. Weekends are ordinary calendar days.
    public func streaks(today: Date, threshold: Double = 600) -> (current: Int, best: Int, todayCounted: Bool) {
        let todayKey = FocusDayKey.key(today, calendar: calendar)
        let qualifying = days.values.filter { $0.id <= todayKey && $0.focus + 0.001 >= threshold }.map(\.id).sorted()
        let counted = qualifying.contains(todayKey)
        let start = counted ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var cursor = start
        var current = 0
        let set = Set(qualifying)
        while set.contains(FocusDayKey.key(cursor, calendar: calendar)) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        var best = 0
        var run = 0
        var previous: Date?
        for key in qualifying {
            guard let date = FocusDayKey.date(key, calendar: calendar) else { continue }
            let consecutive = previous.map { calendar.dateComponents([.day], from: $0, to: date).day == 1 } ?? false
            run = consecutive ? run + 1 : 1
            best = max(best, run)
            previous = date
        }
        return (current, best, counted)
    }
}

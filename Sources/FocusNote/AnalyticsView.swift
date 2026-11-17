import Charts
import SwiftUI
import FocusNoteKit

struct AnalyticsView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedDay: Date?
    @State private var selectedChartDay: Double?
    @State private var scrollPosition = ScrollPosition(edge: .top)
    private var data: FocusAnalytics { model.insights.data }
    private var calendar: Calendar { data.calendar }
    private var today: Date { .now }
    private var week: FocusWeekSummary { data.week(containing: model.analyticsDate, now: today) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Analytics").font(.largeTitle.weight(.semibold))
                    Text("Your time locked in.").foregroundStyle(.secondary)
                }
                .gridProbe("analyticsHeading", area: "analytics")
                streakSection.gridProbe("analyticsStreak", area: "analytics")
                heatmapSection.gridProbe("analyticsHeatmap", area: "analytics")
                weeklySection.gridProbe("analyticsWeeklyChart", area: "analytics")
                if let error = model.insights.error {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry") { Task { await model.insights.refresh(container: model.container) } }
                } else if !model.insights.loaded {
                    ProgressView("Loading focus history…")
                }
                if data.days.values.contains(where: \.approximate) {
                    Text("Older activity placement is approximate; recorded duration is preserved.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Focus excludes breaks, pauses, sleep, and offline time. Dates use \(data.timeZoneID).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(Space.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridArea("analytics", inset: Space.margin)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollPosition($scrollPosition)
        .onReceive(NotificationCenter.default.publisher(for: .snapshotPageScroll)) { note in
            scrollPosition.scrollTo(edge: (note.object as? Bool) == true ? .bottom : .top)
        }
        .task { await model.insights.refresh(container: model.container) }
        .onReceive(NotificationCenter.default.publisher(for: .focusRecordsChanged)) { _ in
            Task { await model.insights.refresh(container: model.container) }
        }
    }

    private var streakSection: some View {
        let streak = data.streaks(today: today)
        return DashboardCard {
            Text("Streaks").font(.headline)
            HStack(alignment: .firstTextBaseline) {
                Text("\(streak.current) days").font(.title.weight(.semibold)).monospacedDigit()
                Spacer()
                Text("Best: \(streak.best) days").font(.callout).foregroundStyle(.secondary)
            }
            Text(streak.todayCounted ? "You’ve locked in today." : "Lock in for 10 minutes today to \(streak.current > 0 ? "continue" : "start").")
                .font(.caption).foregroundStyle(.secondary)
            Text("10 minutes of actual focus earns a streak day. Weekends count.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var heatmapSection: some View {
        let starts = heatmapWeeks
        let dates = starts.flatMap { start in (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) } }
        let summaries = dates.filter { $0 <= today }.map { data.day($0) }
        let high = summaries.filter { $0.planAchievement == .aboveEighty }.count
        let medium = summaries.filter { $0.planAchievement == .aboveHalf }.count
        return DashboardCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Plan consistency").font(.headline)
                Spacer()
                Text("Last 52 weeks").font(.caption).foregroundStyle(.secondary)
            }
            Text("\(high) days above 80% · \(medium) days above 50% up to 80%")
                .font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: Space.sm) {
                VStack(spacing: DashboardStyle.heatmapGap) {
                    Color.clear.frame(height: Space.lg)
                    ForEach(0..<7) { day in
                        Text(["Mon", "", "Wed", "", "Fri", "", ""][day])
                            .font(.system(size: 10))
                            .frame(height: DashboardStyle.heatmapCell)
                    }
                }
                .padding(.vertical, Space.xs)
                .frame(width: 28, alignment: .leading)
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: DashboardStyle.heatmapGap) {
                        ForEach(starts, id: \.self) { start in
                            VStack(spacing: DashboardStyle.heatmapGap) {
                                Color.clear.frame(height: Space.lg)
                                    .overlay(alignment: .leading) {
                                        if calendar.component(.day, from: start) <= 7 {
                                            Text(start.formatted(.dateTime.month(.abbreviated)))
                                                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize()
                                        }
                                    }
                                ForEach(0..<7) { index in
                                    if let date = calendar.date(byAdding: .day, value: index, to: start) { heatmapCell(date) }
                                }
                            }
                            .frame(width: DashboardStyle.heatmapCell)
                        }
                    }
                    .padding(.vertical, Space.xs)
                }
                .defaultScrollAnchor(.trailing)
                .scrollBounceBehavior(.basedOnSize)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.md) { heatmapLegend }
                VStack(alignment: .leading, spacing: Space.sm) { heatmapLegend }
            }
            Text("Scroll for earlier weeks. Select a day to inspect its plan.")
                .font(.caption).foregroundStyle(.secondary)
            if let selectedDay {
                let day = data.day(selectedDay)
                Text("\(selectedDay.formatted(.dateTime.month().day().year())): \(FocusDuration.text(day.focus)) actual / \(FocusDuration.text(day.planned)) planned · \(achievementText(day))")
                    .font(.caption)
            }
        }
    }

    @ViewBuilder private var heatmapLegend: some View {
        legendSquare("≤50%", color: DashboardStyle.heatmapNeutral)
        legendSquare(">50%", color: DashboardStyle.lightGreen)
        legendSquare(">80%", color: DashboardStyle.actualGreen)
        legendSquare("No plan", color: .clear)
    }

    private func legendSquare(_ title: String, color: Color) -> some View {
        HStack(spacing: Space.xs) {
            RoundedRectangle(cornerRadius: DashboardStyle.heatmapRadius)
                .fill(color)
                .overlay { RoundedRectangle(cornerRadius: DashboardStyle.heatmapRadius).strokeBorder(.secondary.opacity(0.4)) }
                .frame(width: DashboardStyle.heatmapCell, height: DashboardStyle.heatmapCell)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func heatmapCell(_ date: Date) -> some View {
        let day = data.day(date)
        let future = date > today
        let color: Color = switch day.planAchievement {
        case .aboveEighty: DashboardStyle.actualGreen
        case .aboveHalf: DashboardStyle.lightGreen
        case .belowHalf: DashboardStyle.heatmapNeutral
        case .noPlan: .clear
        }
        let description = "\(date.formatted(date: .complete, time: .omitted)): \(FocusDuration.text(day.focus)) actual, \(FocusDuration.text(day.planned)) planned, \(achievementText(day))"
        return Button {
            selectedDay = date
            model.analyticsDate = date
            selectedChartDay = nil
        } label: {
            RoundedRectangle(cornerRadius: DashboardStyle.heatmapRadius)
                .fill(future ? Color.clear : color)
                .overlay {
                    RoundedRectangle(cornerRadius: DashboardStyle.heatmapRadius)
                        .strokeBorder(selectedDay.map { calendar.isDate(date, inSameDayAs: $0) } == true ? Color.primary : Color.secondary.opacity(future ? 0.1 : 0.3))
                }
                .frame(width: DashboardStyle.heatmapCell, height: DashboardStyle.heatmapCell)
        }
        .buttonStyle(.plain)
        .disabled(future)
        .help(description)
        .accessibilityLabel(description)
    }

    private var heatmapWeeks: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        return (-51...0).compactMap { calendar.date(byAdding: .weekOfYear, value: $0, to: start) }
    }

    private var weeklySection: some View {
        let week = week // Freeze the dates for chart/lazy callbacks.
        let maximum = max(1, ceil((week.days.map { max($0.focus, $0.planned) }.max() ?? 0) / 3_600 * 1.1))
        return DashboardCard {
            Text("Planned vs actual").font(.headline)
            HStack(spacing: Space.sm) {
                Button("Previous Week", systemImage: "chevron.left") { shiftWeek(-1) }
                    .labelStyle(.iconOnly).help("Show the previous week (⌥⌘←)")
                Text(weekTitle(week)).font(.headline).frame(maxWidth: .infinity).lineLimit(1).help(weekTitle(week))
                Button("Next Week", systemImage: "chevron.right") { shiftWeek(1) }
                    .labelStyle(.iconOnly).help("Show the next week (⌥⌘→)")
                    .disabled(calendar.isDate(model.analyticsDate, equalTo: today, toGranularity: .weekOfYear) || model.analyticsDate > today)
                Button("This Week") { model.analyticsDate = today; selectedChartDay = nil }
                    .help("Return to the current week")
            }
            .controlSize(.small)
            Chart {
                ForEach(Array(week.dates.enumerated()), id: \.element) { index, date in
                    let day = week.days[index]
                    RectangleMark(xStart: .value("Day", Double(index) - 0.32), xEnd: .value("Day", Double(index) + 0.32),
                                  yStart: .value("Hours", 0), yEnd: .value("Planned hours", day.planned / 3_600))
                        .foregroundStyle(DashboardStyle.plannedGreen)
                        .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide))), planned")
                        .accessibilityValue(FocusDuration.text(day.planned))
                    RectangleMark(xStart: .value("Day", Double(index) - 0.32), xEnd: .value("Day", Double(index) + 0.32),
                                  yStart: .value("Hours", 0), yEnd: .value("Actual hours", day.focus / 3_600))
                        .foregroundStyle(DashboardStyle.actualGreen)
                        .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide))), actual")
                        .accessibilityValue(FocusDuration.text(day.focus))
                }
                RuleMark(y: .value("Average planned hours", week.averagePlanned / 3_600))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .accessibilityLabel("Average planned per day")
                    .accessibilityValue(FocusDuration.text(week.averagePlanned))
                RuleMark(y: .value("Average actual hours", week.averageActual / 3_600))
                    .foregroundStyle(DashboardStyle.greenText)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 3]))
                    .accessibilityLabel("Average actual per day")
                    .accessibilityValue(FocusDuration.text(week.averageActual))
            }
            .chartXScale(domain: -0.6...6.6)
            .chartYScale(domain: 0...maximum)
            .chartXAxis {
                AxisMarks(values: Array(0...6)) { value in
                    AxisValueLabel {
                        if let index = value.as(Int.self), week.dates.indices.contains(index) {
                            Text(week.dates[index].formatted(.dateTime.weekday(.abbreviated)))
                        }
                    }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartYAxisLabel("Hours", position: .leading)
            .chartXSelection(value: $selectedChartDay)
            .frame(height: DashboardStyle.weekChartHeight)
            HStack(spacing: Space.lg) {
                legendSquare("Planned", color: DashboardStyle.plannedGreen)
                legendSquare("Actual", color: DashboardStyle.actualGreen)
            }
            VStack(alignment: .leading, spacing: Space.sm) {
                averageLegend("Average planned", seconds: week.averagePlanned, actual: false)
                averageLegend("Average actual", seconds: week.averageActual, actual: true)
            }
            Text(week.elapsedDays < 7 ? "Averages use elapsed days this week, not future days." : "Averages use all 7 calendar days.")
                .font(.caption).foregroundStyle(.secondary)
            if week.days.allSatisfy({ $0.focus == 0 && $0.planned == 0 }) {
                Text("No focus or plans recorded this week.").font(.caption).foregroundStyle(.secondary)
            }
            if let index = selectedChartDay.map({ Int($0.rounded()) }), week.dates.indices.contains(index) {
                let day = week.days[index]
                Text("\(week.dates[index].formatted(.dateTime.weekday(.wide))): \(FocusDuration.text(day.focus)) actual / \(FocusDuration.text(day.planned)) planned")
                    .font(.caption)
            }
        }
    }

    private func averageLegend(_ title: String, seconds: Double, actual: Bool) -> some View {
        HStack(spacing: Space.sm) {
            Path { path in path.move(to: .zero); path.addLine(to: CGPoint(x: 28, y: 0)) }
                .stroke(actual ? DashboardStyle.greenText : .secondary, style: StrokeStyle(lineWidth: 2, dash: actual ? [2, 3] : [6, 4]))
                .frame(width: 28, height: 2)
            Text("\(title): \(FocusDuration.text(seconds)) / day").font(.caption).monospacedDigit()
        }
    }

    private func weekTitle(_ week: FocusWeekSummary) -> String {
        "\(week.dates[0].formatted(.dateTime.month().day())) – \(week.dates[6].formatted(.dateTime.month().day().year()))"
    }

    private func shiftWeek(_ direction: Int) {
        model.analyticsDate = calendar.date(byAdding: .weekOfYear, value: direction, to: model.analyticsDate) ?? model.analyticsDate
        selectedChartDay = nil
    }

    private func achievementText(_ day: FocusDaySummary) -> String {
        day.planned > 0 ? "\(Int(day.focus / day.planned * 100))% of plan" : "No plan"
    }
}

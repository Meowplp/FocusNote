import SwiftData
import SwiftUI
import FocusNoteKit

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undo
    @Query(sort: \DailyList.key, order: .reverse) private var lists: [DailyList]
    @Query(sort: \Item.createdAt) private var items: [Item]
    @State private var scrollPosition = ScrollPosition(edge: .top)

    private var keys: [String] {
        Set(lists.filter { $0.archivedAt != nil }.map(\.key))
            .union(model.insights.data.days.keys.filter { $0 < model.dailyLists.activeKey }).sorted(by: >)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let key = model.historyKey { detail(key) }
                else { overview }
                if let error = model.insights.error ?? model.saveError {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry") {
                        if model.saveError != nil { model.save() }
                        else { Task { await model.insights.refresh(container: model.container) } }
                    }
                }
            }
            .padding(Space.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridArea("history", inset: Space.margin)
        }
        .id(model.historyKey ?? "overview")
        .scrollBounceBehavior(.basedOnSize)
        .scrollPosition($scrollPosition)
        .onReceive(NotificationCenter.default.publisher(for: .snapshotPageScroll)) { note in
            scrollPosition.scrollTo(edge: (note.object as? Bool) == true ? .bottom : .top)
        }
        .onChange(of: model.historyKey) { _, _ in scrollPosition.scrollTo(edge: .top) }
        .task { await model.insights.refresh(container: model.container) }
        .onReceive(NotificationCenter.default.publisher(for: .focusRecordsChanged)) { _ in
            Task { await model.insights.refresh(container: model.container) }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("History").font(.largeTitle.weight(.semibold))
                Text("Your lists, kept day by day.").foregroundStyle(.secondary)
            }
            .gridProbe("historyHeading", area: "history")
            if keys.isEmpty {
                ContentUnavailableView("No archived lists yet", systemImage: "clock.arrow.circlepath",
                                       description: Text("Your previous list will appear here when you open FocusNote on a new day."))
            } else {
                ForEach(keys, id: \.self) { key in
                    let day = model.insights.data.days[key] ?? FocusDaySummary(id: key)
                    let tasks = items.filter { $0.dayKey == key && !$0.isReminder && !$0.isTrashed }
                    Button {
                        model.historyKey = key
                    } label: {
                        DashboardCard {
                            HStack(alignment: .firstTextBaseline) {
                                Text(dateTitle(key)).font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            Text("\(FocusDuration.text(day.focus)) focused · \(day.pomodoros) Pomodoros")
                            Text("\(tasks.filter(\.isCompleted).count)/\(tasks.count) tasks completed")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("View the list for \(dateTitle(key))")
                    .gridProbe("historyDay-\(key)", area: "history", edge: "days")
                }
            }
        }
    }

    private func detail(_ key: String) -> some View {
        let rows = items.filter { $0.dayKey == key && !$0.isTrashed }
        let day = model.insights.data.days[key] ?? FocusDaySummary(id: key)
        return VStack(alignment: .leading, spacing: Space.xl) {
            Button("All History", systemImage: "chevron.left") { model.historyKey = nil }
                .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(dateTitle(key)).font(.title.weight(.semibold))
                Text("Saved list · Read-only").font(.caption).foregroundStyle(.secondary)
                Text("\(FocusDuration.text(day.focus)) focused / \(FocusDuration.text(day.planned)) planned")
                if day.approximate {
                    Text("Older activity timing is approximate. Recorded duration is preserved.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .gridProbe("historyDetailHeading", area: "history")
            if let list = lists.first(where: { $0.key == key }) {
                Text("\(list.timeZoneInferred ? "Inferred list time zone (migration)" : "List time zone"): \(list.timeZoneID)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach([false, true], id: \.self) { notes in
                DashboardCard {
                    Text(notes ? "To Remember" : "To Do").font(.headline)
                    let section = rows.filter { $0.isReminder == notes }
                    if section.isEmpty { Text("No items.").foregroundStyle(.secondary) }
                    ForEach(section, id: \.uuid) { item in
                        HStack(alignment: .top, spacing: Space.sm) {
                            Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                .foregroundStyle(item.isCompleted ? Palette.accent : .secondary)
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(item.title).strikethrough(item.isCompleted)
                                if !notes {
                                    Text("\(item.completedPomodoros)/\(item.plannedSessions) Pomodoros · \(item.focusMinutes)m focus")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.title), \(item.isCompleted ? "completed" : "unfinished")")
                        Divider()
                    }
                    if model.dailyLists.archivedKeys.contains(key) {
                        Button(notes ? "Copy Unchecked Notes to Today" : "Copy Unfinished Tasks to Today") {
                            model.copyUnfinished(from: key, notes: notes, undo: undo)
                        }
                        .disabled(section.allSatisfy(\.isCompleted))
                        .help("Create fresh items in today’s list; keep this saved list unchanged")
                    }
                }
                .gridProbe(notes ? "historyNoteCard" : "historyTaskCard", area: "history", edge: "cards")
            }
            Text("Activity by calendar day is available in Analytics. Focus after midnight belongs to the day it happened.")
                .font(.caption).foregroundStyle(.secondary)
            SessionHistoryView(sessions: model.insights.data.sessions.filter { session in
                rows.contains { $0.uuid == session.taskID }
            }, titles: model.insights.data.titles)
        }
    }

    private func dateTitle(_ key: String) -> String {
        (FocusDayKey.date(key)?.formatted(.dateTime.weekday(.wide).month(.wide).day().year())) ?? key
    }
}

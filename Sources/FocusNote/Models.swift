import Foundation
import SwiftData
import FocusNoteKit

@Model
final class Item {
    var title: String
    var notes: String = ""
    var isStarred: Bool = false
    var createdAt: Date = Date.now
    /// A stable id for links, sync, and the agent CLI.
    var uuid: UUID = UUID()
    var plannedSessions: Int = 4
    /// Rebuildable projection of completed focus history, never break/partial time.
    var completedPomodoros: Int = 0
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 20
    var isCompleted: Bool = false
    var isReminder: Bool = false
    var isTrashed: Bool = false
    var listDate: Date = Date.now
    var dayKey: String = ""
    var copiedFromID: UUID?

    init(title: String, isReminder: Bool = false) {
        self.title = title
        self.isReminder = isReminder
        if isReminder { plannedSessions = 0 }
    }

    var focusPlan: FocusPlan {
        FocusPlan(sessions: plannedSessions, focusMinutes: focusMinutes,
                  shortBreakMinutes: shortBreakMinutes, longBreakMinutes: longBreakMinutes)
    }

    var plannedFocusCount: Int { isReminder ? 0 : plannedSessions }
}

/// The sidebar pages. Snapshot mode walks through every case.
enum SidebarItem: String, CaseIterable, Identifiable {
    case all, starred, history, analytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Today"
        case .starred: "Completed"
        case .history: "History"
        case .analytics: "Analytics"
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray"
        case .starred: "star"
        case .history: "clock.arrow.circlepath"
        case .analytics: "chart.bar"
        }
    }
}

/// App-wide state that menus, toolbars, and views share.
@Observable
final class AppModel {
    let container: ModelContainer
    let timer: PomodoroController
    let timerPanel: TimerPanelController
    let dailyLists: DailyListStore
    let insights = AnalyticsStore()
    var rollover: DayRollover?
    /// Snapshot-only pose; normal rollover animation owns its progress in the view.
    var rolloverPreviewProgress: Double?
    var dayNotice: String?
    var historyKey: String?
    var analyticsDate: Date = .now
    var sidebar: SidebarItem? = .all
    var selection: UUID?
    var selectedDate: Date = Date.now
    var addingTask = false
    var addingReminder = false
    var saveError: String?
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { if !Store.isOverridden { UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab") } }
    }

    init(container: ModelContainer) {
        self.container = container
        timer = PomodoroController(container: container)
        timerPanel = TimerPanelController(timer: timer)
        dailyLists = DailyListStore(context: container.mainContext)
        AppDelegate.timer = timer
        AppDelegate.model = self
    }

    func openTimer(_ item: Item) {
        guard !item.isReminder && canEdit(item) else { return }
        timer.openTask(item)
        timerPanel.show()
    }

    func addItem(title: String = "", isReminder: Bool = false) {
        guard rollover == nil else { return }
        let key = FocusDayKey.key(selectedDate)
        guard dailyLists.activeKey.isEmpty || key == dailyLists.activeKey else { return }
        let item = Item(title: ItemTitle.clean(title), isReminder: isReminder)
        item.listDate = selectedDate
        item.dayKey = FocusDayKey.key(selectedDate)
        container.mainContext.insert(item)
        selection = item.uuid
        save()
    }

    func beginAddingTask() {
        guard rollover == nil else { return }
        addingReminder = false
        addingTask = true
        sidebar = .all
        selectActiveDay()
    }

    func beginAddingReminder() {
        guard rollover == nil else { return }
        addingTask = false
        addingReminder = true
        sidebar = .all
        selectActiveDay()
    }

    func save() {
        do {
            try container.mainContext.save()
            NotificationCenter.default.post(name: .focusRecordsChanged, object: nil)
            saveError = nil
        } catch {
            saveError = "Unable to save changes. Try again."
        }
    }

    func rename(_ item: Item, to title: String, undo: UndoManager?) {
        guard canEdit(item) else { return }
        let clean = ItemTitle.clean(title)
        let previous = item.title
        guard clean != previous else { return }
        undo?.registerUndo(withTarget: self) { $0.rename(item, to: previous, undo: undo) }
        undo?.setActionName(item.isReminder ? "Edit Note" : "Rename Task")
        item.title = clean
        save()
    }

    @discardableResult
    func setFocusPlan(_ item: Item, to plan: FocusPlan, undo: UndoManager?) -> Bool {
        guard canEdit(item) && !item.isReminder && plan.isValid else { return false }
        let previous = item.focusPlan
        guard previous != plan else {
            save()
            return saveError == nil
        }
        undo?.registerUndo(withTarget: self) { $0.setFocusPlan(item, to: previous, undo: undo) }
        undo?.setActionName("Change Focus Plan")
        item.plannedSessions = plan.sessions
        item.focusMinutes = plan.focusMinutes
        item.shortBreakMinutes = plan.shortBreakMinutes
        item.longBreakMinutes = plan.longBreakMinutes
        timer.planChanged(item)
        save()
        return saveError == nil
    }

    func setCompleted(_ item: Item, _ completed: Bool, undo: UndoManager?) {
        guard canEdit(item) else { return }
        let previous = item.isCompleted
        undo?.registerUndo(withTarget: self) { $0.setCompleted(item, previous, undo: undo) }
        undo?.setActionName(item.isReminder ? "Complete Note" : "Complete Task")
        item.isCompleted = completed
        if completed && !item.isReminder { timer.taskCompleted(item) }
        save()
    }

    func setDeleted(_ item: Item, _ deleted: Bool, undo: UndoManager?) {
        guard canEdit(item) else { return }
        let previous = item.isTrashed
        undo?.registerUndo(withTarget: self) { $0.setDeleted(item, previous, undo: undo) }
        undo?.setActionName(item.isReminder ? "Delete Note" : "Delete Task")
        item.isTrashed = deleted
        if deleted && timer.taskID == item.uuid { timer.cancelCurrent() }
        save()
    }

    func canEdit(_ item: Item) -> Bool {
        !dailyLists.archivedKeys.contains(item.dayKey) && rollover == nil
    }

    func selectActiveDay() {
        selectedDate = FocusDayKey.date(dailyLists.activeKey) ?? .now
    }

    func openDailyList(now: Date = .now, animate: Bool = true) {
        guard rollover == nil else { return }
        if let transition = dailyLists.prepare(now: now, stopTimer: {
            timer.cancelCurrent()
            if timer.error == nil { timer.panel?.orderOut(nil) }
            return timer.error == nil
        }) {
            addingTask = false
            addingReminder = false
            sidebar = .all
            if animate {
                selectedDate = FocusDayKey.date(transition.previousKey) ?? now
                rollover = transition
            } else {
                selectedDate = FocusDayKey.date(transition.nextKey) ?? now
            }
        } else if dailyLists.error == nil {
            selectActiveDay()
        }
    }

    func finishRollover() {
        guard let rollover else { return }
        selectedDate = FocusDayKey.date(rollover.nextKey) ?? .now
        self.rollover = nil
        dayNotice = "Previous list saved to History."
    }

    func copyUnfinished(from key: String, notes: Bool = false, undo: UndoManager? = nil) {
        guard rollover == nil, dailyLists.archivedKeys.contains(key) else { return }
        do {
            try container.mainContext.save()
            let items = try container.mainContext.fetch(FetchDescriptor<Item>())
            let copied = Set(items.filter { $0.dayKey == dailyLists.activeKey && !$0.isTrashed }.compactMap(\.copiedFromID))
            let originals = items.filter {
                $0.dayKey == key && !$0.isCompleted && !$0.isTrashed && $0.isReminder == notes && !copied.contains($0.uuid)
            }
            var additions: [Item] = []
            for original in originals {
                let item = Item(title: original.title, isReminder: original.isReminder)
                item.notes = original.notes
                item.plannedSessions = original.plannedSessions
                item.focusMinutes = original.focusMinutes
                item.shortBreakMinutes = original.shortBreakMinutes
                item.longBreakMinutes = original.longBreakMinutes
                item.dayKey = dailyLists.activeKey
                item.listDate = FocusDayKey.date(item.dayKey) ?? .now
                item.copiedFromID = original.uuid
                container.mainContext.insert(item)
                additions.append(item)
            }
            save()
            if saveError != nil {
                container.mainContext.rollback()
                return
            }
            if saveError == nil {
                dayNotice = originals.isEmpty ? "Already copied or nothing unfinished." : "Copied \(originals.count) to today."
                if !additions.isEmpty {
                    undo?.registerUndo(withTarget: self) { model in
                        for item in additions { model.setDeleted(item, true, undo: undo) }
                    }
                    undo?.setActionName(notes ? "Copy Notes to Today" : "Copy Tasks to Today")
                }
            }
        } catch {
            saveError = "Unable to copy tasks. Try again."
        }
    }
}

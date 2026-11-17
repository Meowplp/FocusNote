import SwiftData
import SwiftUI
import FocusNoteKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Item.createdAt) private var items: [Item]
    @State private var newTitle = ""
    @State private var newNoteTitle = ""
    private enum EntryField: Hashable { case task, note }
    @FocusState private var entryFocus: EntryField?

    private var visible: [Item] {
        items.filter {
            !$0.isTrashed && ($0.dayKey.isEmpty ? Calendar.current.isDate($0.listDate, inSameDayAs: model.selectedDate)
                               : $0.dayKey == FocusDayKey.key(model.selectedDate))
                && (model.sidebar != .starred || $0.isCompleted)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
                .padding(.bottom, Space.xxl)
                .gridProbe("heading", area: "note")
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.xl) {
                        dailySection(isReminder: false)
                            .gridProbe("todoSection", area: "listSections")
                        dailySection(isReminder: true)
                            .gridProbe("rememberSection", area: "listSections")
                    }
                    .gridArea("listSections", inset: 0)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: model.addingTask) { _, adding in
                    if adding {
                        model.addingReminder = false
                        Task { @MainActor in
                            await Task.yield()
                            guard model.addingTask else { return }
                            proxy.scrollTo("new-task", anchor: .bottom)
                            entryFocus = .task
                        }
                    }
                }
                .onChange(of: model.addingReminder) { _, adding in
                    if adding {
                        model.addingTask = false
                        Task { @MainActor in
                            await Task.yield()
                            guard model.addingReminder else { return }
                            proxy.scrollTo("new-note", anchor: .bottom)
                            entryFocus = .note
                        }
                    }
                }
            }
            .gridProbe("tasks", area: "note")
            if let error = model.saveError {
                HStack {
                    Text(error)
                    Button("Retry") { model.save() }
                }
                .font(.caption)
                .padding(.vertical, Space.sm)
            }
            Divider()
            HStack {
                let tasks = visible.filter { !$0.isReminder }
                Label("\(visible.reduce(0) { $0 + $1.plannedFocusCount }) planned", systemImage: "timer")
                Spacer()
                let completed = tasks.filter(\.isCompleted).count
                Text("\(completed) \(completed == 1 ? "task" : "tasks") complete")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, Space.lg)
            .accessibilityElement(children: .combine)
        }
        .padding(Space.margin)
        .gridArea("note")
        .background(NoteStyle.paper)
        .noInitialFocus()
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(Calendar.current.isDateInToday(model.selectedDate) ? "Today" : model.selectedDate.formatted(.dateTime.month(.wide).day()))
                .font(.largeTitle.weight(.semibold))
            Text(model.selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .foregroundStyle(.secondary)
        }
    }

    private func dailySection(isReminder: Bool) -> some View {
        let rows = visible.filter { $0.isReminder == isReminder }
        let adding = isReminder ? model.addingReminder : model.addingTask
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(isReminder ? "To Remember" : "To Do")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !rows.isEmpty {
                    Text("\(rows.filter(\.isCompleted).count)/\(rows.count)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(rows.filter(\.isCompleted).count) of \(rows.count) checked off")
                }
            }
            .padding(.vertical, Space.sm)
            if rows.isEmpty && !adding {
                Text(model.sidebar == .starred ? "Nothing checked off yet."
                     : (isReminder ? "Keep small reminders here." : "Plan your focus here."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Space.md)
            }
            ForEach(rows, id: \.uuid) { item in
                TaskRow(item: item)
            }
            if adding {
                newItemField(isReminder: isReminder)
                    .id(isReminder ? "new-note" : "new-task")
            } else {
                Button {
                    if isReminder { model.beginAddingReminder(); entryFocus = .note }
                    else { model.beginAddingTask(); entryFocus = .task }
                } label: {
                    Label(isReminder ? "Add Note" : "Add Task", systemImage: "plus")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Space.md)
                }
                .buttonStyle(.plain)
                .help(isReminder ? "Add a note to To Remember (⇧⌘N)" : "Add a task to To Do (⌘N)")
            }
        }
    }

    private func newItemField(isReminder: Bool) -> some View {
        HStack(spacing: Space.md) {
            Image(systemName: "square").foregroundStyle(.secondary)
            TextField(isReminder ? "What would you like to remember?" : "What would you like to do?",
                      text: isReminder ? $newNoteTitle : $newTitle)
                .font(NoteStyle.noteFont)
                .textFieldStyle(.plain)
                .focused($entryFocus, equals: isReminder ? .note : .task)
                .onSubmit { addItem(isReminder: isReminder) }
                .onExitCommand {
                    if isReminder { model.addingReminder = false; newNoteTitle = "" }
                    else { model.addingTask = false; newTitle = "" }
                    entryFocus = nil
                }
                .accessibilityLabel(isReminder ? "New note" : "New task title")
                .help("Type and press Return to add it; Escape cancels")
        }
        .padding(.vertical, Space.lg)
    }

    private func addItem(isReminder: Bool) {
        let title = isReminder ? newNoteTitle : newTitle
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.addItem(title: title, isReminder: isReminder)
        if isReminder { newNoteTitle = ""; entryFocus = .note }
        else { newTitle = ""; entryFocus = .task }
    }
}

private struct TaskRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undo
    let item: Item
    @State private var editing = false
    @State private var draft = ""
    @State private var showingPlan = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Space.md) {
            Toggle("Complete \(item.title)", isOn: Binding(
                get: { item.isCompleted },
                set: { model.setCompleted(item, $0, undo: undo) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            VStack(alignment: .leading, spacing: Space.sm) {
                if editing {
                    TextField(item.isReminder ? "Note" : "Task title", text: $draft)
                        .font(NoteStyle.noteFont)
                        .textFieldStyle(.plain)
                        .focused($titleFocused)
                        .onSubmit(commit)
                        .onExitCommand { editing = false }
                        .onChange(of: titleFocused) { _, focused in if !focused { commit() } }
                } else {
                    Text(item.title)
                        .font(NoteStyle.noteFont)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .lineLimit(item.isReminder ? 2 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { beginEditing() }
                        .focusable()
                        .onKeyPress(.return) { beginEditing(); return .handled }
                        .accessibilityAction(named: Text(item.isReminder ? "Edit Note" : "Edit Task Name")) { beginEditing() }
                        .help("Double-click to edit “\(item.title)”; press Return when focused")
                }
                if !item.isReminder {
                    Button {
                        showingPlan = true
                    } label: {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("\(item.completedPomodoros) of \(item.plannedSessions) Pomodoros · \(item.focusMinutes) min focus")
                            Text(item.plannedSessions > 1
                                 ? "\(item.plannedSessions - 1) × \(item.shortBreakMinutes) min breaks · \(item.longBreakMinutes) min long"
                                 : "\(item.longBreakMinutes) min long break")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Set this task's Pomodoros, focus duration, and breaks")
                    .popover(isPresented: $showingPlan) {
                        TaskPlanEditor(item: item)
                    }
                }
            }
            if !item.isReminder && (!item.isCompleted || (model.timer.taskID == item.uuid && model.timer.countdown?.phase != .finished)) {
                Button {
                    model.openTimer(item)
                } label: {
                    Image(systemName: item.isCompleted ? "timer" : "play.circle")
                }
                .buttonStyle(.plain)
                .font(.title3)
                .help("Open the timer for “\(item.title)”")
                .accessibilityLabel(item.isCompleted ? "Show timer for \(item.title)" : "Focus on \(item.title)")
            }
            Menu {
                if !item.isReminder {
                    Button("Edit Focus Plan") { showingPlan = true }
                    Divider()
                }
                Button(item.isReminder ? "Delete Note" : "Delete Task", role: .destructive) { model.setDeleted(item, true, undo: undo) }
            } label: { Image(systemName: "ellipsis") }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(item.isReminder ? "Show note actions" : "Show task actions")
            .accessibilityLabel("Actions for \(item.title)")
        }
        .frame(minHeight: item.isReminder ? NoteStyle.reminderRowHeight : NoteStyle.rowHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(NoteStyle.rule).frame(height: 1) }
        .contextMenu {
            if !item.isReminder {
                Button("Edit Focus Plan") { showingPlan = true }
            }
            Button(item.isReminder ? "Delete Note" : "Delete Task", role: .destructive) { model.setDeleted(item, true, undo: undo) }
        }
    }

    private func beginEditing() {
        draft = item.title
        editing = true
        titleFocused = true
    }

    private func commit() {
        guard editing else { return }
        if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.rename(item, to: draft, undo: undo)
        }
        editing = false
    }
}

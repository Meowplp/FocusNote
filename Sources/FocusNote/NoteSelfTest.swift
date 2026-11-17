import AppKit
import FocusNoteKit
import SwiftData

enum NoteSelfTest {
    static func run(model: AppModel, note: Item, check: (String, Bool) -> Void) {
        let timer = model.timer
        timer.stopClock()
        timer.preferences.startTaskAutomatically = false
        let work = Item(title: "Uninterrupted focus")
        model.container.mainContext.insert(work)
        model.save()
        timer.openTask(work, now: 100)
        timer.start(now: 100)
        check("To Remember notes contribute zero planned Pomodoros", note.plannedFocusCount == 0)
        check("notes have no completed Pomodoro projection", note.completedPomodoros == 0)
        check("existing To Do items retain Pomodoro plans", !work.isReminder && work.plannedFocusCount == 4)

        let undo = UndoManager()
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        model.setCompleted(note, true, undo: undo)
        undo.endUndoGrouping()
        check("a To Remember note can be checked manually", note.isCompleted)
        check("checking a note never starts a break or interrupts focus",
              timer.taskID == work.uuid && timer.countdown?.phase == .focus && timer.countdown?.status == .running)
        undo.undo()
        check("Undo reopens a checked note", !note.isCompleted)
        let planBefore = note.focusPlan
        check("notes reject focus-plan edits", !model.setFocusPlan(note, to: FocusPlan(sessions: 8), undo: nil)
              && note.focusPlan == planBefore)
        timer.openTask(note, now: 100)
        model.openTimer(note)
        check("both timer entry points refuse notes without switching tasks", timer.taskID == work.uuid)
        check("notes never create Pomodoro history", timer.completedCount(for: note.uuid) == 0)
        model.rename(note, to: "  Remember   the umbrella ", undo: nil)
        check("notes support inline rename", note.title == "Remember the umbrella")
        undo.beginUndoGrouping()
        model.setDeleted(note, true, undo: undo)
        undo.endUndoGrouping()
        check("deleting a note hides it without interrupting focus", note.isTrashed && timer.taskID == work.uuid)
        undo.undo()
        check("Undo restores a deleted note", !note.isTrashed)
        let saved = try? ModelContext(model.container).fetch(FetchDescriptor<Item>()).first { $0.uuid == note.uuid }
        check("note kind, title, and date persist", saved?.isReminder == true && saved?.title == note.title
              && saved?.listDate == note.listDate)
        timer.cancelCurrent(now: 100)
    }
}

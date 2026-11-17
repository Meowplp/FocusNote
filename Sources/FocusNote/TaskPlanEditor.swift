import FocusNoteKit
import SwiftUI

struct TaskPlanEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undo
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var sessions: String
    @State private var focus: String
    @State private var shortBreak: String
    @State private var longBreak: String

    init(item: Item, initialSessions: String? = nil) {
        self.item = item
        _sessions = State(initialValue: initialSessions ?? String(item.plannedSessions))
        _focus = State(initialValue: String(item.focusMinutes))
        _shortBreak = State(initialValue: String(item.shortBreakMinutes))
        _longBreak = State(initialValue: String(item.longBreakMinutes))
    }

    private var plan: FocusPlan? {
        guard let count = Int(sessions), let work = Int(focus),
              let short = Int(shortBreak), let long = Int(longBreak) else { return nil }
        let value = FocusPlan(sessions: count, focusMinutes: work, shortBreakMinutes: short, longBreakMinutes: long)
        return value.isValid ? value : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Focus Plan").font(.headline)
                .gridProbe("planHeading", area: "focusPlan")
            Text(item.title).foregroundStyle(.secondary).lineLimit(1).help(item.title)
            Form {
                field("Pomodoros", text: $sessions, unit: "sessions")
                field("Focus duration", text: $focus, unit: "min")
                field("Short break", text: $shortBreak, unit: "min")
                field("Long break", text: $longBreak, unit: "min")
            }
            .gridProbe("planFields", area: "focusPlan")
            Text(model.saveError ?? (plan == nil ? "Use 1–100 Pomodoros and 1–240 whole minutes." : " "))
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32, alignment: .leading)
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Plan") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(plan == nil)
            }
        }
        .padding(Space.margin)
        .frame(width: 360, height: 300, alignment: .topLeading)
        .gridArea("focusPlan")
        .noInitialFocus()
        .onSubmit(save)
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private func field(_ title: String, text: Binding<String>, unit: String) -> some View {
        LabeledContent(title) {
            HStack(spacing: Space.sm) {
                TextField(title, text: text)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .accessibilityLabel(title)
                Text(unit).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
            }
        }
    }

    private func save() {
        guard let plan, model.setFocusPlan(item, to: plan, undo: undo) else { return }
        dismiss()
    }
}

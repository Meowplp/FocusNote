import AppKit
import FocusNoteKit
import SwiftUI

final class TimerPanelController {
    // AppModel is initialized while SwiftUI evaluates the App's state graph.
    // Creating/restoring an AppKit window there can re-enter that graph and abort.
    private(set) lazy var panel: NSPanel = makePanel()
    private(set) var isPanelCreated = false
    private let timer: PomodoroController
    private let frameAutosaveName: String?
    private var didRestoreFrame = false

    init(timer: PomodoroController, frameAutosaveName: String? = nil) {
        self.timer = timer
        self.frameAutosaveName = frameAutosaveName ?? (Store.isOverridden ? nil : "compact-focus-timer-v2")
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: NoteStyle.timerDefaultSize),
                            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.title = "Focus Timer"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = timer.preferences.keepOnTop ? .floating : .normal
        panel.contentMinSize = NoteStyle.timerMinimumSize
        panel.center()
        let host = NSHostingView(rootView: TimerPanelView(timer: timer).themed())
        host.sizingOptions = []
        panel.contentView = host
        timer.panel = panel
        isPanelCreated = true
        return panel
    }

    func show() {
        let panel = panel
        // This runs from a post-launch task or user action, with content attached,
        // never from AppModel/App @State initialization. Keep existing geometry.
        if !didRestoreFrame {
            didRestoreFrame = true
            if let frameAutosaveName {
                panel.setFrameAutosaveName(frameAutosaveName)
                panel.setFrameUsingName(frameAutosaveName)
            }
        }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) { panel.center() }
        panel.orderFrontRegardless()
    }
}

struct TimerPanelView: View {
    @Bindable var timer: PomodoroController

    private var phaseTitle: String {
        guard let clock = timer.countdown else { return "Choose a Task" }
        switch clock.phase {
        case .focus: return "Focus \(min(clock.completedSessions + 1, clock.plan.sessions))/\(clock.plan.sessions)"
        case .shortBreak: return "Break \(clock.completedSessions)/\(max(1, clock.plan.sessions - 1))"
        case .longBreak: return "Long Break"
        case .finished: return "Complete"
        }
    }

    private var digits: String {
        let seconds = Int(ceil(timer.countdown?.remaining ?? 0))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = TimerLayout(width: geometry.size.width, height: geometry.size.height)
            let inset = layout.compact ? Space.sm : Space.lg
            if timer.completionID != nil {
                TimerCompletionView(confirmed: timer.completionConfirmed)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: layout.compact ? Space.xs : Space.md) {
                    Text(timer.task?.title ?? "Choose a task from your list")
                        .font(.system(size: layout.compact ? 11 : 13, weight: .semibold))
                        .lineLimit(1)
                        .help(timer.task?.title ?? "Choose a task")
                    ClockFace(phase: phaseTitle, digits: digits, state: stateDescription,
                              digitSize: layout.digitSize, compact: layout.compact)
                        .frame(height: ClockFace.height(digitSize: layout.digitSize, compact: layout.compact))
                        .gridProbe("clockFace", area: "timer")
                    controls(compact: layout.compact)
                    if !layout.compact, let message = timer.message {
                        Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    footer
                }
                .padding(inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .gridArea("timer", inset: inset)
            }
        }
        .background(NoteStyle.timerBackground)
        .frame(minWidth: NoteStyle.timerMinimumSize.width, minHeight: NoteStyle.timerMinimumSize.height)
        .noInitialFocus()
        .transaction { transaction in
            if timer.completionID == nil {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }

    private func controls(compact: Bool) -> some View {
        HStack(spacing: Space.xs) {
            if let clock = timer.countdown {
                if clock.phase != .finished {
                    Button {
                        if clock.status == .running { timer.pause() } else { timer.start() }
                    } label: {
                        if compact { Image(systemName: clock.status == .running ? "pause.fill" : "play.fill") }
                        else { Text(primaryLabel) }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(primaryLabel)
                    .help("\(primaryLabel) this timer (⇧⌘P)")
                    Button {
                        timer.reset()
                    } label: {
                        if compact { Image(systemName: "arrow.counterclockwise") }
                        else { Text("Reset") }
                    }
                    .accessibilityLabel("Reset Session")
                    .help("Reset this countdown; keep completed Pomodoros")
                    if clock.phase == .shortBreak || clock.phase == .longBreak {
                        Button {
                            timer.skipBreak()
                        } label: {
                            if compact { Image(systemName: "forward.end.fill") }
                            else { Text("Skip Break") }
                        }
                        .accessibilityLabel("Skip Break")
                        .help("Skip this break without adding a Pomodoro")
                    }
                }
                Spacer(minLength: 0)
                if let error = timer.error {
                    Button {
                        timer.retrySave()
                    } label: { Image(systemName: "exclamationmark.triangle") }
                        .help(error)
                        .accessibilityLabel("Unable to save timer progress. Retry")
                } else {
                    Text("\(clock.completedSessions)/\(clock.plan.sessions) done")
                        .font(.system(size: compact ? 10 : 11))
                        .monospacedDigit()
                        .lineLimit(1)
                        .accessibilityLabel("\(clock.completedSessions) of \(clock.plan.sessions) work sessions completed")
                }
            }
        }
        .controlSize(.small)
    }

    private var footer: some View {
        HStack(spacing: Space.xs) {
            Button {
                timer.backToList()
            } label: {
                Image(systemName: "checklist")
                    .frame(minWidth: 20, minHeight: 20)
            }
            .buttonStyle(.plain)
            .help("Back to List")
            .accessibilityLabel("Back to List")
            Spacer(minLength: 0)
            Toggle(isOn: Binding(
                get: { timer.preferences.keepOnTop },
                set: { timer.preferences.keepOnTop = $0; timer.savePreferences() }
            )) { Image(systemName: "pin") }
                .toggleStyle(.checkbox)
                .help("Keep this timer above other windows")
                .accessibilityLabel("Keep on Top")
        }
        .overlay {
            Toggle("Auto", isOn: Binding(
                get: { timer.automaticCycleEnabled },
                set: { timer.setAutomaticCycle($0) }
            ))
            .toggleStyle(.checkbox)
            .fixedSize()
            .help("Automatically start work and breaks until the whole plan is complete")
            .accessibilityLabel("Run the complete plan automatically")
        }
        .font(.system(size: 11))
        .controlSize(.small)
    }

    private var stateDescription: String {
        switch timer.countdown?.status {
        case .ready: "Ready"
        case .running: "Running"
        case .paused: "Paused"
        case .finished: "Done"
        case nil: ""
        }
    }

    private var primaryLabel: String {
        switch timer.countdown?.status {
        case .running: "Pause"
        case .paused: "Resume"
        default: "Start"
        }
    }
}

/// A quiet endpoint inside the existing panel, not a second popup window.
private struct TimerCompletionView: View {
    let confirmed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(confirmed ? Color(nsColor: .systemGreen) : Color.primary)
                .scaleEffect(reduceMotion || appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6), value: appeared)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: confirmed)
                .accessibilityHidden(true)
                .gridProbe("completionMark", area: "", edge: "=completion|")
            Text("All done")
                .font(.headline)
                .gridProbe("completionTitle", area: "", edge: "=completion|")
            Text("Returning to your list")
                .font(.caption)
                .foregroundStyle(.secondary)
                .gridProbe("completionDetail", area: "", edge: "=completion|")
        }
        .padding(Space.lg)
        .gridArea("completion", inset: Space.lg)
        .accessibilityElement(children: .combine)
        .onAppear { appeared = true }
    }
}

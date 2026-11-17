import AppKit
import SwiftData
import SwiftUI

// FocusNote
//   FocusNote                      the app
//   APP_STORE=<file> FocusNote     use another database (tests, experiments)
//   APP_SNAPSHOT=<dir> FocusNote   save a PNG of every sidebar page and Settings tab in light and dark mode, then quit
//   APP_SEED=1 FocusNote           fill an empty /tmp store with sample items (tools/snap.sh)
//   FocusNote --selftest           run the self-test on a /tmp store and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> FocusNote      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 FocusNote           draw the 8 pt grid and the layout probes over the window

@main
struct FocusNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel(container: Store.makeContainer())

    var body: some Scene {
        let timerAvailable = model.timer.countdown != nil
        let timerFinished = model.timer.countdown?.phase == .finished
        let timerAction = model.timer.countdown?.status == .running ? "Pause Timer" : "Start or Resume Timer"
        let transitioning = model.rollover != nil
        let currentAnalyticsWeek = model.insights.data.calendar.isDate(model.analyticsDate, equalTo: .now, toGranularity: .weekOfYear)
        Window("FocusNote", id: "main") {
            AppShellView()
                .environment(model)
                .themed()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 400, minHeight: 480)
        }
        .modelContainer(model.container)
        .defaultSize(width: NoteStyle.windowWidth, height: NoteStyle.windowHeight)
        .windowToolbarStyle(.unified)
        .commands {
            ToolbarCommands()
            CommandGroup(replacing: .newItem) {
                Button("Add Task") { model.beginAddingTask() }
                    .keyboardShortcut("n")
                    .disabled(transitioning)
                Button("Add Note") { model.beginAddingReminder() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(transitioning)
            }
            CommandMenu("Timer") {
                Button("Show Timer") { model.timerPanel.show() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                    .disabled(!timerAvailable)
                Button(timerAction) {
                    if model.timer.countdown?.status == .running { model.timer.pause() }
                    else { model.timer.start() }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(!timerAvailable || timerFinished)
                Button("Reset Session") { model.timer.reset() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(!timerAvailable || timerFinished)
            }
            CommandMenu("Navigate") {
                Button("Show Today") { model.sidebar = .all; model.selectActiveDay() }
                    .keyboardShortcut("1")
                    .disabled(transitioning)
                Button("Show History") { model.sidebar = .history }
                    .keyboardShortcut("2")
                    .disabled(transitioning)
                Button("Show Analytics") { model.sidebar = .analytics }
                    .keyboardShortcut("3")
                    .disabled(transitioning)
                Divider()
                Button("Show Previous Analytics Week") {
                    model.analyticsDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: model.analyticsDate) ?? model.analyticsDate
                    model.sidebar = .analytics
                }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                    .disabled(transitioning)
                Button("Show Next Analytics Week") {
                    let calendar = model.insights.data.calendar
                    if let next = calendar.date(byAdding: .weekOfYear, value: 1, to: model.analyticsDate),
                       calendar.dateInterval(of: .weekOfYear, for: next)!.start <= .now {
                        model.analyticsDate = next
                    }
                    model.sidebar = .analytics
                }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                    .disabled(transitioning || currentAnalyticsWeek)
                Button("Show Current Analytics Week") { model.analyticsDate = .now; model.sidebar = .analytics }
                    .keyboardShortcut("0", modifiers: [.command, .option])
                    .disabled(transitioning)
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var timer: PomodoroController?
    static weak var model: AppModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Started from a terminal, the process is not a foreground app yet.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        SelfTest.requested || Self.timer?.countdown == nil
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if Self.timer?.mainWindow?.isVisible != true { Self.model?.openDailyList() }
        return true
    }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        Self.timer?.pause()
        if SelfTest.requested { exit(SelfTest.exitCode) }
        if TimerPerformanceProbe.requested { exit(TimerPerformanceProbe.exitCode) }
    }
}

/// Where the data lives: ~/Library/Application Support/FocusNote/FocusNote.store
enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let dir = URL.applicationSupportDirectory.appending(path: "FocusNote", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "FocusNote.store")
    }

    static func makeContainer() -> ModelContainer {
        let environment = ProcessInfo.processInfo.environment
        let automated = SelfTest.requested || TimerPerformanceProbe.requested
            || environment["APP_SEED"] == "1"
            || !(environment["APP_SNAPSHOT"] ?? "").isEmpty
        if automated {
            guard isOverridden && TimerPerformanceProbe.isSafeStoreURL(url) else {
                fputs("Automation refused: use APP_STORE in a private temporary directory\n", stderr)
                exit(1)
            }
            let parent = url.deletingLastPathComponent().resolvingSymlinksInPath()
            let attributes = try? FileManager.default.attributesOfItem(atPath: parent.path)
            let permissions = (attributes?[.posixPermissions] as? NSNumber)?.intValue ?? 0
            let owner = (attributes?[.ownerAccountID] as? NSNumber)?.uint32Value
            guard owner == getuid(), permissions & 0o077 == 0 else {
                fputs("Automation refused: database parent must be owned by you with mode 0700\n", stderr)
                exit(1)
            }
            // SQLite also follows symlinks for its journal/sidecar files.
            for suffix in ["", "-wal", "-shm", "-journal"] {
                let candidate = URL(fileURLWithPath: url.path + suffix)
                if (try? candidate.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                    fputs("Automation refused: database files must not be symlinks\n", stderr)
                    exit(1)
                }
            }
            if let output = environment["APP_SNAPSHOT"], !output.isEmpty {
                let destination = URL(fileURLWithPath: output).resolvingSymlinksInPath().path
                guard destination.hasPrefix(parent.path + "/") else {
                    fputs("Automation refused: snapshots must stay inside the private store directory\n", stderr)
                    exit(1)
                }
            }
        }
        do {
            return try ModelContainer(for: Item.self, FocusAttempt.self, TimerRecovery.self, TimerPreferences.self,
                                      DailyList.self, DailyListState.self, FocusInterval.self,
                                      configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Could not open the database at \(url.path): \(error)")
        }
    }
}

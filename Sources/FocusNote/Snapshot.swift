import AppKit
import IOKit.pwr_mgt
import QuartzCore
import SwiftData
import SwiftUI
import FocusNoteKit

/// Screenshot mode for agents.
///   APP_STORE=/tmp/test.store APP_SNAPSHOT=/tmp/shots ~/Applications/FocusNote.app/Contents/MacOS/FocusNote
/// writes <page>-light.png and <page>-dark.png for every sidebar page, and
/// settings-<tab>-light.png and settings-<tab>-dark.png for every Settings tab, then quits.
/// Each PNG gets a <page>-<mode>-layout.json with the grid probes (tools/check-layout.swift).
/// APP_SNAPSHOT_PAGES=all,starred limits the pages. Add "settings" to include Settings.
/// Add APP_ACCENT=<id> to see the pages in another accent.
enum Snapshot {
    private static var launched = false
    static func runIfRequested(model: AppModel, openSettings: OpenSettingsAction) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"], !dir.isEmpty else { return }
        guard !launched else { return }
        launched = true
        // Snapshots never run against the real database.
        guard Store.isOverridden else {
            print("SNAPSHOT refused: set APP_STORE to a file in /tmp")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        Task {
            // Keep the test app's layout/display active during view rendering.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1.5))
            let mainWindow = NSApp.windows.first { $0.canBecomeMain && !$0.isSheet && !($0 is NSPanel) }
            mainWindow?.animationBehavior = .none
            mainWindow?.setContentSize(NSSize(width: NoteStyle.windowWidth, height: NoteStyle.windowHeight))
            mainWindow?.center()
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                for page in SidebarItem.allCases where only?.contains(page.rawValue) ?? true {
                    model.sidebar = page
                    try? await Task.sleep(for: .seconds(0.8))
                    await capture(to: "\(dir)/\(page.rawValue)-\(mode).png", window: mainWindow)
                }
            }
            if only == nil || only?.contains("notes") == true {
                model.sidebar = .all
                mainWindow?.setContentSize(NSSize(width: 560, height: 840))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    await capture(to: "\(dir)/today-notes-\(mode).png", window: mainWindow, scrollToBottom: true)
                }
                mainWindow?.setContentSize(NSSize(width: NoteStyle.windowWidth, height: NoteStyle.windowHeight))
            }
            if only == nil || only?.contains("analytics") == true {
                await model.insights.refresh(container: model.container)
                model.sidebar = .analytics
                mainWindow?.setContentSize(NSSize(width: 560, height: 960))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    model.analyticsDate = .now
                    await capture(to: "\(dir)/analytics-dashboard-\(mode).png", window: mainWindow)
                    await capture(to: "\(dir)/analytics-chart-\(mode).png", window: mainWindow, scrollToBottom: true)
                    model.analyticsDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: .now)!
                    await capture(to: "\(dir)/analytics-previous-week-\(mode).png", window: mainWindow, scrollToBottom: true)
                    model.analyticsDate = Calendar.current.date(byAdding: .weekOfYear, value: -100, to: .now)!
                    await capture(to: "\(dir)/analytics-empty-\(mode).png", window: mainWindow)
                }
                model.analyticsDate = .now
                mainWindow?.setContentSize(NSSize(width: NoteStyle.windowWidth, height: NoteStyle.windowHeight))
            }
            if only == nil || only?.contains("history") == true {
                model.sidebar = .history
                let key = FocusDayKey.key(Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
                model.historyKey = key
                mainWindow?.setContentSize(NSSize(width: 560, height: 840))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    await capture(to: "\(dir)/history-detail-\(mode).png", window: mainWindow)
                }
                model.historyKey = nil
                mainWindow?.setContentSize(NSSize(width: NoteStyle.windowWidth, height: NoteStyle.windowHeight))
            }
            if only == nil || only?.contains("plan") == true,
               let item = try? model.container.mainContext.fetch(FetchDescriptor<Item>()).first(where: { $0.plannedSessions == 5 }) {
                let host = NSHostingView(rootView: TaskPlanEditor(item: item)
                    .environment(model).modelContainer(model.container).themed())
                let editor = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                                      styleMask: [.titled], backing: .buffered, defer: false)
                editor.title = "Focus Plan"
                editor.contentView = host
                editor.center()
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    await capture(to: "\(dir)/task-plan-\(mode).png", window: editor)
                }
                editor.orderOut(nil)
                let invalidHost = NSHostingView(rootView: TaskPlanEditor(item: item, initialSessions: "")
                    .environment(model).modelContainer(model.container).themed())
                let invalidEditor = NSWindow(contentRect: NSRect(origin: .zero, size: invalidHost.fittingSize),
                                             styleMask: [.titled], backing: .buffered, defer: false)
                invalidEditor.title = "Focus Plan"
                invalidEditor.contentView = invalidHost
                invalidEditor.center()
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    await capture(to: "\(dir)/task-plan-empty-field-\(mode).png", window: invalidEditor)
                }
                invalidEditor.orderOut(nil)
            }
            if only == nil || only?.contains("timer") == true,
               let item = try? model.container.mainContext.fetch(FetchDescriptor<Item>()).first(where: { $0.plannedSessions == 5 }) {
                let timer = model.timer
                timer.stopClock()
                timer.automaticallyDismissCompletion = false
                timer.preferences.startTaskAutomatically = false
                timer.preferences.startBreaksAutomatically = false
                timer.preferences.startNextFocusAutomatically = false
                timer.openTask(item, now: 0)
                model.timerPanel.show()
                let panel = model.timerPanel.panel
                panel.setContentSize(NoteStyle.timerDefaultSize)
                panel.center()
                @MainActor func pair(_ name: String) async {
                    for mode in ["light", "dark"] {
                        NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                        await capture(to: "\(dir)/timer-\(name)-\(mode).png", window: panel)
                    }
                }
                await pair("ready")
                timer.setAutomaticCycle(true, now: 0)
                await pair("auto")
                timer.setAutomaticCycle(false, now: 0)
                var now = 0.0
                timer.start(now: now)
                now += 62
                timer.tick(now: now)
                await pair("running")
                timer.pause(now: now)
                await pair("paused")
                panel.setContentSize(NoteStyle.timerMinimumSize)
                await pair("minimum")
                panel.setContentSize(NSSize(width: 360, height: 380))
                await pair("expanded")
                panel.setContentSize(NoteStyle.timerDefaultSize)
                timer.start(now: now)
                now += timer.countdown?.remaining ?? 0
                timer.tick(now: now)
                await pair("short-break")
                model.sidebar = .all
                if let mainWindow {
                    for mode in ["light", "dark"] {
                        NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                        await capture(to: "\(dir)/task-progress-\(mode).png", window: mainWindow)
                    }
                }
                while timer.countdown?.phase != .longBreak && timer.countdown?.phase != .finished {
                    timer.start(now: now)
                    now += timer.countdown?.remaining ?? 0
                    timer.tick(now: now)
                }
                await pair("long-break")
                model.sidebar = .all
                if let mainWindow {
                    for mode in ["light", "dark"] {
                        NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                        await capture(to: "\(dir)/task-auto-completed-\(mode).png", window: mainWindow)
                    }
                }
                timer.start(now: now)
                now += timer.countdown?.remaining ?? 0
                timer.tick(now: now)
                await pair("finished")
                panel.setContentSize(NoteStyle.timerMinimumSize)
                await pair("finished-minimum")
                if let id = timer.completionID { timer.finishCompletion(id: id) }
                if let mainWindow {
                    for mode in ["light", "dark"] {
                        NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                        await capture(to: "\(dir)/task-returned-\(mode).png", window: mainWindow)
                    }
                }
                timer.cancelCurrent(now: now)
                panel.orderOut(nil)
            }
            if only == nil || only?.contains("settings") == true {
                let main = mainWindow
                openSettings()
                try? await Task.sleep(for: .seconds(1))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for tab in SettingsTab.allCases {
                        model.settingsTab = tab
                        try? await Task.sleep(for: .seconds(0.8))
                        let settings = NSApp.windows.first { $0.isVisible && $0 !== main && $0.canBecomeKey && !$0.isSheet }
                        if let settings {
                            await capture(to: "\(dir)/settings-\(tab.rawValue)-\(mode).png", window: settings)
                        } else {
                            print("SNAPSHOT no Settings window")
                        }
                    }
                }
            }
            if only == nil || only?.contains("rollover") == true {
                model.sidebar = .all
                model.rolloverPreviewProgress = 0.45
                let nextDate = FocusDayKey.calendar().date(byAdding: .day, value: 1, to: .now)!
                model.openDailyList(now: nextDate)
                if let transition = model.rollover {
                    for variant in 0...2 {
                        model.rollover = DayRollover(previousKey: transition.previousKey, nextKey: transition.nextKey, variant: variant)
                        for mode in ["light", "dark"] {
                            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                            await capture(to: "\(dir)/rollover-fold-\(variant)-\(mode).png", window: mainWindow)
                        }
                    }
                    model.finishRollover()
                    model.rolloverPreviewProgress = nil
                    for mode in ["light", "dark"] {
                        NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                        await capture(to: "\(dir)/rollover-new-day-\(mode).png", window: mainWindow)
                    }
                }
            }
            print("SNAPSHOT done \(dir)")
            // An open sheet refuses terminate, and the run would wait forever.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    /// Render only our own AppKit/SwiftUI views. Deliberately never invoke
    /// screencapture or ScreenCaptureKit: ad-hoc rebuilds must not cause recurring
    /// Screen Recording prompts. System glass is not a pixel-exact capture.
    private static func capture(to path: String, window: NSWindow? = nil, scrollToBottom: Bool = false) async {
        // Another app can hide this one while snapshots run (computer use hides
        // apps it does not control). Hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window = window ?? NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) else {
            print("SNAPSHOT no window")
            return
        }
        // Active, like a window someone is using: real accent colors and focus rings.
        NSApp.activate()
        window.animationBehavior = .none
        // Snapshot-only: keep the window out of Stage Manager's parked stack.
        // This process exits after capture; normal windows keep native behavior.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        _ = NSRunningApplication.current.activate(options: [.activateAllWindows])
        window.contentView?.needsDisplay = true
        window.displayIfNeeded()
        // Let native controls and hosted SwiftUI finish layout/appearance updates.
        try? await Task.sleep(for: .seconds(1.5))
        NotificationCenter.default.post(name: .snapshotPageScroll, object: scrollToBottom)
        try? await Task.sleep(for: .milliseconds(300))
        window.makeKey()
        // Flush static AppKit displays after the appearance/layout transaction,
        // not before it. Otherwise the view cache can contain a cleared backing.
        @MainActor func redrawClocks(in view: NSView) {
            if let clock = view as? ClockFace.Face { clock.display() }
            for child in view.subviews { redrawClocks(in: child) }
        }
        if let content = window.contentView { redrawClocks(in: content) }
        CATransaction.flush()
        try? await Task.sleep(for: .milliseconds(200))
        let size = window.contentView?.bounds.size ?? .zero
        // A deliberately transformed 3D pose is visually reviewed, not a static
        // alignment fixture. The flat old/new pages still get full grid checks.
        if !URL(fileURLWithPath: path).lastPathComponent.hasPrefix("rollover-fold-") {
            GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: size)
        }
        do {
            let data = try OwnWindowSnapshot.png(window: window)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            print("SNAPSHOT \(path) (own-view render; no screen permission)")
        } catch {
            print("SNAPSHOT failed \(path): \(error)")
        }
    }
}

import AppKit
import SwiftData

/// Opt-in release-build probe. Never reads or changes the normal user store.
enum TimerPerformanceProbe {
    static let requested = CommandLine.arguments.contains("--timer-performance")
    static var exitCode: Int32 = 0
    private static var collecting = false
    private static var launched = false
    private static var ticks: [Double] = []
    private static var saves: [Double] = []
    private static var fetches = 0
    private static var frameTimes: [Double] = []
    private static var lastDigits: String?
    private static var lastSeconds: Int?
    private static var skipped = 0
    private static var heartbeatDelays: [Double] = []
    private static var lastHeartbeat = 0.0
    private static var started = 0.0

    static func isSafeStoreURL(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        let normalStore = URL.applicationSupportDirectory.appending(path: "FocusNote/FocusNote.store")
            .resolvingSymlinksInPath().path
        guard path != normalStore else { return false }
        let roots = [FileManager.default.temporaryDirectory, URL(fileURLWithPath: "/tmp", isDirectory: true)]
        return roots.contains {
            let root = $0.resolvingSymlinksInPath().path
            return path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
    }

    static func recordTick(_ seconds: Double) {
        if collecting { ticks.append(seconds * 1_000) }
    }

    static func recordSave(_ seconds: Double) {
        if collecting { saves.append(seconds * 1_000) }
    }

    static func recordTaskFetch() {
        if collecting { fetches += 1 }
    }

    static func recordFrame(_ digits: String) {
        guard collecting, digits != lastDigits else { return }
        let components = digits.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return }
        let seconds = components[0] * 60 + components[1]
        if let lastSeconds { skipped += max(0, lastSeconds - seconds - 1) }
        lastSeconds = seconds
        lastDigits = digits
        frameTimes.append(ProcessInfo.processInfo.systemUptime)
    }

    static func runIfRequested(model: AppModel) {
        guard requested && !launched else { return }
        launched = true
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden && isSafeStoreURL(Store.url) else {
            print("PERFORMANCE refused: set APP_STORE to an isolated temporary database")
            exitCode = 1
            NSApp.terminate(nil)
            return
        }
        Task { @MainActor in
            let context = model.container.mainContext
            guard (try? context.fetchCount(FetchDescriptor<Item>())) == 0,
                  (try? context.fetchCount(FetchDescriptor<FocusAttempt>())) == 0 else {
                print("PERFORMANCE refused: use an empty temporary database")
                exitCode = 1
                NSApp.terminate(nil)
                return
            }
            let priorDay = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
            var historyItems: [Item] = []
            for index in 0..<100 {
                let item = Item(title: "Performance fixture \(index)")
                item.plannedSessions = 100
                item.listDate = index < 5 ? .now : priorDay
                context.insert(item)
                historyItems.append(item)
            }
            for index in 0..<2_000 {
                let attempt = FocusAttempt(taskID: historyItems[index % historyItems.count].uuid,
                                           phase: "focus", plannedSeconds: 1_500)
                attempt.outcome = "cancelled"
                attempt.activeSeconds = 15
                attempt.endedAt = .now
                context.insert(attempt)
            }
            let item = Item(title: "Timer performance probe")
            context.insert(item)
            model.save()
            model.timer.preferences.startTaskAutomatically = false
            model.timer.preferences.soundsEnabled = false
            model.timer.openTask(item)
            model.timerPanel.show()
            try? await Task.sleep(for: .seconds(0.8))

            collecting = true
            started = ProcessInfo.processInfo.systemUptime
            lastHeartbeat = started
            let heartbeat = Timer(timeInterval: 0.02, repeats: true) { _ in
                MainActor.assumeIsolated {
                    let now = ProcessInfo.processInfo.systemUptime
                    heartbeatDelays.append(max(0, now - lastHeartbeat - 0.02) * 1_000)
                    lastHeartbeat = now
                }
            }
            heartbeat.tolerance = 0.001
            RunLoop.main.add(heartbeat, forMode: .common)
            RunLoop.main.add(heartbeat, forMode: .modalPanel)
            model.timer.start()
            try? await Task.sleep(for: .seconds(12))
            collecting = false
            heartbeat.invalidate()
            let gaps = zip(frameTimes, frameTimes.dropFirst()).map { ($1 - $0) * 1_000 }
            print("PERFORMANCE fixture: 101 tasks, 2000 history attempts, 12 seconds, release build")
            print(String(format: "PERFORMANCE tick max %.3f ms; p95 %.3f ms", ticks.max() ?? 0, percentile(ticks)))
            print(String(format: "PERFORMANCE save max %.3f ms; p95 %.3f ms", saves.max() ?? 0, percentile(saves)))
            print("PERFORMANCE task-fetches \(fetches); visible skipped labels \(skipped)")
            print(String(format: "PERFORMANCE frame gap max %.3f ms; first frame %.3f ms",
                         gaps.max() ?? 0, (frameTimes.first.map { $0 - started } ?? 0) * 1_000))
            print(String(format: "PERFORMANCE main-loop delay max %.3f ms; p95 %.3f ms",
                         heartbeatDelays.max() ?? 0, percentile(heartbeatDelays)))
            model.timer.cancelCurrent()
            NSApp.terminate(nil)
        }
    }

    private static func percentile(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))]
    }
}

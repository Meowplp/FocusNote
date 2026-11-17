import Foundation
import Observation
import SwiftData
import FocusNoteKit

extension Notification.Name {
    static let focusRecordsChanged = Notification.Name("FocusNote.focusRecordsChanged")
    static let snapshotPageScroll = Notification.Name("FocusNote.snapshotPageScroll")
}

@ModelActor
actor AnalyticsReader {
    func load() throws -> FocusAnalytics {
        let items = try modelContext.fetch(FetchDescriptor<Item>())
        let lists = try modelContext.fetch(FetchDescriptor<DailyList>())
        let attempts = try modelContext.fetch(FetchDescriptor<FocusAttempt>())
        let intervals = try modelContext.fetch(FetchDescriptor<FocusInterval>())
        var samples: [FocusSample] = []
        var partial: [FocusSample] = []
        let byAttempt = Dictionary(grouping: intervals, by: \.attemptID)
        for attempt in attempts {
            var parts = (byAttempt[attempt.uuid] ?? []).map {
                FocusSample(taskID: $0.taskID, start: $0.start, end: $0.end, seconds: $0.activeSeconds,
                            isBreak: $0.phase != "focus", approximate: $0.approximate)
            }
            let recorded = parts.reduce(0) { $0 + $1.seconds }
            // Resuming a legacy paused attempt must preserve its earlier duration.
            let remainder = max(0, attempt.activeSeconds - recorded)
            if remainder > 0.001 {
                parts.append(FocusSample(taskID: attempt.taskID, start: attempt.startedAt,
                                         end: attempt.endedAt ?? attempt.startedAt, seconds: remainder,
                                         isBreak: attempt.phase != "focus", approximate: true))
            }
            samples += parts
            if attempt.phase == "focus" && attempt.outcome != "completed" { partial += parts }
        }
        let plans = lists.map { list in
            FocusPlanSample(key: list.key, seconds: list.archivedAt != nil ? list.plannedSeconds :
                items.filter { $0.dayKey == list.key && !$0.isReminder && !$0.isTrashed }
                    .reduce(0) { $0 + Double($1.plannedSessions * $1.focusMinutes * 60) })
        }
        return FocusAnalytics(samples: samples, plans: plans,
                              completions: attempts.filter { $0.phase == "focus" && $0.outcome == "completed" }
                                .map { FocusCompletion(date: $0.endedAt ?? $0.startedAt) },
                              tasks: items.map {
                                  FocusTaskInfo(id: $0.uuid, title: $0.title, dayKey: $0.dayKey,
                                                planned: $0.isReminder || $0.isTrashed ? 0 : Double($0.plannedSessions * $0.focusMinutes * 60))
                              },
                              partialSamples: partial,
                              sessions: attempts.map {
                                  FocusSessionInfo(id: $0.uuid, taskID: $0.taskID, start: $0.startedAt, end: $0.endedAt,
                                                   seconds: $0.activeSeconds, phase: $0.phase, outcome: $0.outcome)
                              }.sorted { $0.start > $1.start })
    }
}

@Observable
final class AnalyticsStore {
    private(set) var data = FocusAnalytics(samples: [], plans: [], completions: [])
    private(set) var error: String?
    private(set) var loaded = false
    @ObservationIgnored private var revision = 0

    func refresh(container: ModelContainer) async {
        revision += 1
        let current = revision
        do {
            let result = try await AnalyticsReader(modelContainer: container).load()
            guard current == revision else { return }
            data = result
            loaded = true
            error = nil
        } catch {
            guard current == revision else { return }
            self.error = "Unable to load focus history. Try again."
        }
    }
}

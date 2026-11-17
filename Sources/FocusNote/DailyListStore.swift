import Foundation
import Observation
import SwiftData
import FocusNoteKit

struct DayRollover: Identifiable {
    let id = UUID()
    let previousKey: String
    let nextKey: String
    let variant: Int
}

/// Owns migration and the archive/create transaction. Views never delete a day.
@Observable
final class DailyListStore {
    private(set) var activeKey = ""
    private(set) var archivedKeys: Set<String> = []
    private(set) var error: String?
    private var state: DailyListState?
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func bootstrap(now: Date = .now) throws {
        let calendar = FocusDayKey.calendar()
        let today = FocusDayKey.key(now, calendar: calendar)
        let items = try context.fetch(FetchDescriptor<Item>())
        var lists = try context.fetch(FetchDescriptor<DailyList>())
        let states = try context.fetch(FetchDescriptor<DailyListState>())
        let inferredKeys = Set(items.filter { $0.dayKey.isEmpty }.map { FocusDayKey.key($0.listDate, calendar: calendar) })
        let state = states.first ?? DailyListState()
        if state.modelContext == nil { context.insert(state) }
        for item in items where item.dayKey.isEmpty {
            item.dayKey = FocusDayKey.key(item.listDate, calendar: calendar)
        }
        let keys = Set(items.map(\.dayKey))
        for key in keys where !lists.contains(where: { $0.key == key }) {
            let list = DailyList(key: key, date: FocusDayKey.date(key) ?? now)
            list.timeZoneInferred = inferredKeys.contains(key)
            context.insert(list)
            lists.append(list)
        }
        if state.activeKey.isEmpty {
            state.activeKey = keys.filter { $0 <= today }.max() ?? today
        }
        if !lists.contains(where: { $0.key == state.activeKey }) {
            let list = DailyList(key: state.activeKey, date: FocusDayKey.date(state.activeKey) ?? now)
            context.insert(list)
            lists.append(list)
        }
        for list in lists where list.key < state.activeKey && list.archivedAt == nil {
            list.plannedSeconds = planned(items, key: list.key)
            list.archivedAt = now
        }
        try context.save()
        self.state = state
        activeKey = state.activeKey
        archivedKeys = Set(lists.filter { $0.archivedAt != nil }.map(\.key))
        error = nil
    }

    func prepare(now: Date = .now, stopTimer: () -> Bool) -> DayRollover? {
        do {
            try bootstrap(now: now)
            let today = FocusDayKey.key(now)
            guard today != activeKey else { return nil }
            guard today > activeKey else {
                error = "Your system date is earlier than the active list. Your list is unchanged; check Date & Time settings."
                return nil
            }
            guard stopTimer() else {
                error = "Unable to save the previous timer. Retry before starting a new day."
                return nil
            }
            // Flush existing edits before the transaction so rollback below can
            // never discard unrelated pending user changes.
            try context.save()
            let lists = try context.fetch(FetchDescriptor<DailyList>())
            let items = try context.fetch(FetchDescriptor<Item>())
            let oldKey = activeKey
            do {
                if let old = lists.first(where: { $0.key == oldKey }) {
                    old.plannedSeconds = planned(items, key: oldKey)
                    old.archivedAt = now
                }
                let next = lists.first(where: { $0.key == today }) ?? DailyList(key: today, date: now)
                if next.modelContext == nil { context.insert(next) }
                next.archivedAt = nil
                state?.activeKey = today
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
            activeKey = today
            archivedKeys.insert(oldKey)
            archivedKeys.remove(today)
            error = nil
            NotificationCenter.default.post(name: .focusRecordsChanged, object: nil)
            return DayRollover(previousKey: oldKey, nextKey: today, variant: Int.random(in: 0...2))
        } catch {
            self.error = "Unable to save the daily list. Your previous list is preserved. Retry."
            return nil
        }
    }

    private func planned(_ items: [Item], key: String) -> Double {
        items.filter { $0.dayKey == key && !$0.isReminder && !$0.isTrashed }
            .reduce(0) { $0 + Double($1.plannedSessions * $1.focusMinutes * 60) }
    }
}

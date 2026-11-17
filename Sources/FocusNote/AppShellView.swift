import AppKit
import FocusNoteKit
import SwiftUI

struct AppShellView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var folded = false
    @State private var showingDates = false
    @State private var chosenDate = Date.now

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            Picker("Page", selection: $model.sidebar) {
                ForEach([SidebarItem.all, .history, .analytics]) { page in
                    Text(page.title).tag(Optional(page))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, Space.margin)
            .padding(.vertical, Space.md)
            .disabled(model.rollover != nil)
            Divider()
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let error = model.dailyLists.error {
                HStack {
                    Text(error).font(.caption)
                    Button("Retry") { model.openDailyList() }
                }
                .padding(Space.md)
            } else if let notice = model.dayNotice {
                HStack {
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss", systemImage: "xmark") { model.dayNotice = nil }
                        .labelStyle(.iconOnly).buttonStyle(.plain).help("Dismiss this message")
                }
                .padding(Space.md)
            }
        }
        .background(NoteStyle.paper)
        .navigationTitle(model.sidebar?.title ?? "Today")
        .noInitialFocus()
        .toolbar {
            ToolbarItem {
                Button("Choose Day", systemImage: "calendar") { showingDates.toggle() }
                    .disabled(model.rollover != nil)
                    .help("Browse a date in History")
                    .popover(isPresented: $showingDates) {
                        VStack(alignment: .leading, spacing: Space.lg) {
                            Text("Choose Day").font(.headline)
                            DatePicker("Date", selection: $chosenDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                            Button("View Day") {
                                model.historyKey = FocusDayKey.key(chosenDate)
                                model.sidebar = .history
                                showingDates = false
                            }
                        }
                        .padding(Space.margin)
                    }
            }
        }
        .task {
            SeedData.insertIfRequested(into: model)
            model.timer.mainWindow = NSApp.windows.first { $0.canBecomeMain && !($0 is NSPanel) }
            let open = openWindow
            model.timer.revealList = {
                model.sidebar = .all
                model.selectActiveDay()
                open(id: "main")
            }
            if !SelfTest.requested && !TimerPerformanceProbe.requested {
                model.openDailyList(animate: ProcessInfo.processInfo.environment["APP_SNAPSHOT"] == nil)
            } else {
                try? model.dailyLists.bootstrap()
            }
            if model.timer.countdown != nil && !Store.isOverridden { model.timerPanel.show() }
            SelfTest.runIfRequested(model: model)
            TimerPerformanceProbe.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
        }
        .task(id: model.rollover?.id) {
            guard model.rollover != nil else { folded = false; return }
            guard model.rolloverPreviewProgress == nil else { return }
            do {
                try await Task.sleep(for: DashboardStyle.foldLeadPause)
                withAnimation(reduceMotion ? DashboardStyle.fade : DashboardStyle.fold) { folded = true }
                try await Task.sleep(for: reduceMotion ? DashboardStyle.reducedCompletionDelay : DashboardStyle.foldCompletionDelay)
                model.finishRollover()
                folded = false
            } catch { }
        }
        .onChange(of: model.sidebar) { _, page in
            if page == .all && model.rollover == nil { model.selectActiveDay() }
        }
    }

    @ViewBuilder private var page: some View {
        switch model.sidebar {
        case .history: HistoryView()
        case .analytics: AnalyticsView()
        default:
            if let rollover = model.rollover, !reduceMotion {
                let progress = model.rolloverPreviewProgress ?? (folded ? 1.0 : 0.0)
                PaperFoldView(progress: progress, variant: rollover.variant) { ContentView().disabled(true) }
                    .scaleEffect(1 - progress * 0.7)
                    .opacity(1 - progress)
            } else {
                ContentView()
                    .disabled(model.rollover != nil)
                    .opacity(folded ? 0 : 1)
            }
        }
    }
}

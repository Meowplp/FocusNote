import SwiftUI

/// The Settings window (Command-Comma). One tab per topic, at most about
/// six. Each tab is a grouped Form that sizes to its content, so the
/// window grows to fit and shows no scroll bar it does not need.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.settingsTab) {
            ForEach(SettingsTab.allCases) { tab in
                page(tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
        .noInitialFocus()
    }

    @ViewBuilder
    private func page(_ tab: SettingsTab) -> some View {
        Form {
            switch tab {
            case .general: GeneralSettings()
            case .appearance: AppearanceSettings()
            }
        }
        .formStyle(.grouped)
        .fitsContent()
        .frame(width: 520)
    }
}

/// The Settings tabs. Snapshot mode walks through every case.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        }
    }
}

struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var preferences = model.timer.preferences
        Section("Timer") {
            Toggle("Run the whole plan automatically", isOn: Binding(
                get: { model.timer.automaticCycleEnabled },
                set: { model.timer.setAutomaticCycle($0) }
            ))
            Toggle("Play work and break sounds", isOn: $preferences.soundsEnabled)
            HStack {
                Button("Preview Work Sound") { model.timer.previewSound(.work) }
                Button("Preview Break Sound") { model.timer.previewSound(.rest) }
            }
            Toggle("Take a long break when completing a task early", isOn: $preferences.breakAfterTaskCompletion)
            Text("The final planned Pomodoro gets a long break instead of a short break. Switching tasks cancels the current attempt.")
                .foregroundStyle(.secondary)
        }
        .onChange(of: preferences.soundsEnabled) { _, _ in model.timer.savePreferences() }
        .onChange(of: preferences.breakAfterTaskCompletion) { _, _ in model.timer.savePreferences() }
        Section("Daily Lists") {
            Text("Your tasks are saved locally on this Mac.")
            Text("Delete hides a task without erasing its history. Use Edit → Undo to restore it.")
                .foregroundStyle(.secondary)
        }
    }
}

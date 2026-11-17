import SwiftUI
import FocusNoteKit

struct SessionHistoryView: View {
    let sessions: [FocusSessionInfo]
    let titles: [UUID: String]
    var body: some View {
        DashboardCard {
            DisclosureGroup("Session details (\(sessions.count))") {
                if sessions.isEmpty { Text("No recorded sessions.").foregroundStyle(.secondary) }
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: Space.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(titles[session.taskID] ?? "Deleted task").lineLimit(2)
                            Spacer()
                            Text(FocusDuration.text(session.seconds)).monospacedDigit()
                        }
                        Text("\(session.start.formatted(.dateTime.month().day().hour().minute())) · \(session.phase == "focus" ? "Focus" : "Break") · \(outcome(session))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Space.sm)
                    Divider()
                }
            }
        }
    }

    private func outcome(_ session: FocusSessionInfo) -> String {
        switch session.outcome {
        case "completed": "Completed"
        case "cancelled": "Stopped early"
        default: "In progress or paused"
        }
    }
}

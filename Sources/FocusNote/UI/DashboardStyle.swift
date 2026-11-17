import SwiftUI

enum DashboardStyle {
    static let chartHeight: CGFloat = 160
    static let weekChartHeight: CGFloat = 224
    static let heatmapCell: CGFloat = 12
    static let heatmapGap: CGFloat = 4
    static let heatmapRadius: CGFloat = 2
    static var actualGreen: Color { Color(light: 0x238636, dark: 0x3FB950, highContrastLight: 0x176329, highContrastDark: 0x63D879) }
    static var lightGreen: Color { Color(light: 0x9BE9A8, dark: 0x1E6034, highContrastLight: 0x65BD7A, highContrastDark: 0x2A8B48) }
    static var plannedGreen: Color { Color(light: 0xD5EBDD, dark: 0x264232, highContrastLight: 0xA5CDB3, highContrastDark: 0x3A6048) }
    static var greenText: Color { Color(light: 0x176329, dark: 0x63D879) }
    static var heatmapNeutral: Color { Color.primary.opacity(0.08) }
    static let cellHeight: CGFloat = 36
    static let cornerRadius: CGFloat = 12
    static let markRadius: CGFloat = 4
    static let fold = Animation.easeInOut(duration: 0.7)
    static let fade = Animation.easeOut(duration: 0.2)
    static let foldLeadPause: Duration = .milliseconds(150)
    static let foldCompletionDelay: Duration = .milliseconds(750)
    static let reducedCompletionDelay: Duration = .milliseconds(250)
}

enum FocusDuration {
    static func text(_ seconds: Double) -> String {
        let minutes = max(0, Int(seconds / 60))
        if seconds > 0 && minutes == 0 { return "<1m" }
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.lg)
            .background(.background, in: RoundedRectangle(cornerRadius: DashboardStyle.cornerRadius))
            .overlay { RoundedRectangle(cornerRadius: DashboardStyle.cornerRadius).strokeBorder(.quaternary) }
    }
}

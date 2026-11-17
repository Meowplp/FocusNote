import Foundation

public struct TimerLayout: Sendable {
    public let compact: Bool
    public let digitSize: Double

    public init(width: Double, height: Double) {
        compact = width < 280 || height < 280
        let available = min((width - 40) / 3.4, (height - 104) * 0.52)
        digitSize = min(72, max(24, floor(available / 4) * 4))
    }
}

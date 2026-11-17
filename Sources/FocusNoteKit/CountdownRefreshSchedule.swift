import Foundation

public enum CountdownRefreshSchedule {
    /// Delay until the next visible countdown update.
    public static func delay(remaining: TimeInterval) -> TimeInterval {
        guard remaining > 0 else { return 0.005 }
        // Wake just after the next integer boundary. If a callback is early,
        // retry at that same boundary instead of waiting another whole second.
        return max(0.005, remaining - (ceil(remaining) - 1) + 0.005)
    }
}

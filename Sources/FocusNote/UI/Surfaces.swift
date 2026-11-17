import SwiftUI

/// Paper is intentionally warmer than window chrome; controls remain native.
enum NoteStyle {
    static let paper = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.13, alpha: 1)
            : NSColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1)
    })
    static let rule = Color.primary.opacity(0.16)
    static let timerBackground = Color(light: 0xE8E8EA, dark: 0x242426,
                                       highContrastLight: 0xDCDCDD, highContrastDark: 0x151517)
    static let clockBackgroundColor = NSColor.white
    static let clockTextColor = NSColor.black
    static let clockRadius: CGFloat = 12
    static let noteFont = Font.body
    static let timerDefaultSize = CGSize(width: 180, height: 192)
    static let timerMinimumSize = CGSize(width: 160, height: 168)
    static let rowHeight: CGFloat = 76
    static let reminderRowHeight: CGFloat = 44
    static let windowWidth: CGFloat = 480
    static let windowHeight: CGFloat = 640
}

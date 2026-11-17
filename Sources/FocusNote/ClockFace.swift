import AppKit
import SwiftUI

/// A static display, not a custom control, with explicit black-on-white text
/// metrics at compact sizes and a single stable accessibility element.
struct ClockFace: NSViewRepresentable {
    let phase: String
    let digits: String
    let state: String
    let digitSize: CGFloat
    let compact: Bool

    static func height(digitSize: CGFloat, compact: Bool) -> CGFloat {
        let padding = compact ? Space.sm : Space.lg
        return ceil((digitSize * 1.2 + 16 + Space.xs + padding * 2) / 4) * 4
    }

    func makeNSView(context: Context) -> Face {
        let view = Face()
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.staticText)
        return view
    }

    func updateNSView(_ view: Face, context: Context) {
        if TimerPerformanceProbe.requested { TimerPerformanceProbe.recordFrame(digits) }
        view.phase = phase
        view.digits = digits
        view.state = state
        view.digitSize = digitSize
        view.compact = compact
        view.setAccessibilityLabel("\(phase), \(state)")
        view.setAccessibilityValue(digits)
        view.needsDisplay = true
    }

    final class Face: NSView {
        var phase = ""
        var digits = ""
        var state = ""
        var digitSize: CGFloat = 40
        var compact = true
        override var isFlipped: Bool { true }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            needsDisplay = true
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            needsDisplay = true
        }

        override func draw(_ dirtyRect: NSRect) {
            NoteStyle.clockBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: NoteStyle.clockRadius, yRadius: NoteStyle.clockRadius).fill()
            let inset = compact ? Space.sm : Space.lg
            let labelFont = NSFont.systemFont(ofSize: compact ? 10 : 11)
            let labelStyle = NSMutableParagraphStyle()
            labelStyle.lineBreakMode = .byTruncatingTail
            let attributes: [NSAttributedString.Key: Any] = [
                .font: labelFont, .foregroundColor: NoteStyle.clockTextColor, .paragraphStyle: labelStyle,
            ]
            let stateWidth = ceil((state as NSString).size(withAttributes: attributes).width)
            (phase as NSString).draw(in: NSRect(x: inset, y: inset, width: max(0, bounds.width - inset * 2 - stateWidth - Space.sm), height: 16),
                                    withAttributes: attributes)
            (state as NSString).draw(in: NSRect(x: bounds.width - inset - stateWidth, y: inset, width: stateWidth, height: 16),
                                    withAttributes: attributes)
            let center = NSMutableParagraphStyle()
            center.alignment = .center
            center.lineBreakMode = .byClipping
            (digits as NSString).draw(
                in: NSRect(x: inset, y: inset + 16 + Space.xs, width: bounds.width - inset * 2,
                           height: bounds.height - inset * 2 - 16 - Space.xs),
                withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: digitSize, weight: .medium),
                                 .foregroundColor: NoteStyle.clockTextColor, .paragraphStyle: center])
        }
    }
}

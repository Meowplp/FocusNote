// Captioned app-only feature walkthrough from tools/snap.sh sample-data renders.
// Compile: swiftc -parse-as-library tools/make-demo.swift -o /path/to/make-demo
// Usage: /path/to/make-demo <shots-directory> <output.mp4>
import AppKit
import AVFoundation

struct Scene {
    let image: String
    let title: String
    let caption: String
}

@main struct Demo {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("Usage: make-demo <shots-directory> <output.mp4>")
        }
        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        let scenes = [
            Scene(image: "all-light", title: "FocusNote",
                  caption: "A daily checklist and a calmer focus routine. Local on your Mac."),
            Scene(image: "today-notes-light", title: "Today · To Do + To Remember",
                  caption: "Keep planned tasks separate from quick reminders. Check, rename, delete, and Undo."),
            Scene(image: "task-plan-light", title: "Make a plan for each task",
                  caption: "Choose focus count and focus, short-break, and long-break durations."),
            Scene(image: "timer-ready-light", title: "A floating focus timer",
                  caption: "Open a task's timer and keep it nearby while you work."),
            Scene(image: "timer-auto-light", title: "Auto · run the whole plan",
                  caption: "Enable automatic focus and break transitions, or start each phase yourself."),
            Scene(image: "timer-running-light", title: "Focus, pause, resume",
                  caption: "Actual time counts active work, not paused time. Reset starts the current phase over."),
            Scene(image: "timer-minimum-light", title: "Small when you need space",
                  caption: "Resize the floating timer. Your checklist stays available behind it."),
            Scene(image: "timer-short-break-light", title: "Take a short break",
                  caption: "Short breaks separate focus sessions. Skip a break without earning extra focus credit."),
            Scene(image: "task-auto-completed-light", title: "Finish the planned work",
                  caption: "The final focus checks off the task. A long break closes the plan."),
            Scene(image: "timer-finished-light", title: "Celebrate, then return",
                  caption: "A green checkmark finishes the cycle; the timer closes and Today comes forward."),
            Scene(image: "rollover-fold-0-light", title: "A fresh list each day",
                  caption: "A paper-fold transition archives the previous day. Tasks never silently carry forward."),
            Scene(image: "history-detail-light", title: "History · preserve past days",
                  caption: "Read previous lists. Explicitly copy unfinished tasks or notes to Today, with Undo."),
            Scene(image: "analytics-dashboard-light", title: "Analytics · see your rhythm",
                  caption: "Track streaks and 52 weeks of plan achievement, without inventing work on empty days."),
            Scene(image: "analytics-chart-light", title: "Planned versus actual",
                  caption: "Compare weekly focus hours and averages. Browse previous weeks to see your progress."),
            Scene(image: "settings-general-light", title: "Choose your timer behavior",
                  caption: "Auto, mute, sound previews, and early-completion breaks. One focus burst; a short break ding."),
            Scene(image: "settings-appearance-dark", title: "Make it yours",
                  caption: "Choose your accent. Light and dark appearance follow your Mac. No account or cloud required."),
            Scene(image: "all-dark", title: "FocusNote · early beta",
                  caption: "Open source for macOS 26+. Fictional sample data; scripted still-image walkthrough.")
        ]
        // Fail before encoding if any expected app render is missing.
        let images = try scenes.map { scene -> NSImage in
            let url = source.appendingPathComponent(scene.image + ".png")
            guard let image = NSImage(contentsOf: url) else {
                throw NSError(domain: "Demo", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Missing \(url.lastPathComponent)"])
            }
            return image
        }
        let width = 1920, height = 1080
        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 3_000_000]
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error! }
        writer.startSession(atSourceTime: .zero)
        for (index, scene) in scenes.enumerated() {
            let frame = try render(scene, image: images[index], width: width, height: height)
            // Nine seconds per scene; duplicate stills provide broad player compatibility.
            for second in 0..<9 {
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing else { throw writer.error! }
                    try await Task.sleep(for: .milliseconds(10))
                }
                guard adaptor.append(frame, withPresentationTime: CMTime(value: Int64(index * 9 + second), timescale: 1)) else {
                    throw writer.error!
                }
            }
        }
        writer.endSession(atSourceTime: CMTime(value: Int64(scenes.count * 9), timescale: 1))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error! }
        print("Created \(output.path) · 1920×1080 · \(scenes.count * 9) seconds · no recorded screen/audio")
    }

    @MainActor static func render(_ scene: Scene, image: NSImage, width: Int, height: Int) throws -> CVPixelBuffer {
        var result: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32ARGB,
                            [kCVPixelBufferCGImageCompatibilityKey: true,
                             kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &result)
        guard let buffer = result else { throw NSError(domain: "Demo", code: 2) }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            throw NSError(domain: "Demo", code: 3)
        }
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSColor(calibratedRed: 0.055, green: 0.065, blue: 0.085, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        func text(_ value: String, size: CGFloat, weight: NSFont.Weight, y: CGFloat, height: CGFloat, color: NSColor) {
            (value as NSString).draw(in: NSRect(x: 100, y: y, width: 1720, height: height), withAttributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color, .paragraphStyle: paragraph
            ])
        }
        text(scene.title, size: 40, weight: .semibold, y: 984, height: 60, color: .white)
        let available = NSSize(width: 1600, height: 770)
        let scale = min(available.width / image.size.width, available.height / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: NSRect(x: (1920 - size.width) / 2, y: 180 + (770 - size.height) / 2,
                              width: size.width, height: size.height))
        text(scene.caption, size: 28, weight: .regular, y: 70, height: 90, color: .white)
        text("FICTIONAL DATA  ·  SCRIPTED WALKTHROUGH  ·  TIMER STATES ADVANCED FOR DEMONSTRATION",
             size: 16, weight: .medium, y: 20, height: 28, color: .lightGray)
        return buffer
    }
}

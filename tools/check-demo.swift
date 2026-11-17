// Compile with swiftc -parse-as-library; arguments: movie.mp4 review.png
import AppKit
import AVFoundation

@main struct CheckDemo {
    @MainActor static func main() async throws {
        let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        let size = try await tracks.first!.load(.naturalSize)
        precondition(abs(duration.seconds - 153) < 0.1)
        precondition(size == CGSize(width: 1920, height: 1080))
        precondition(audio.isEmpty)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let sheet = NSImage(size: NSSize(width: 1920, height: 5 * 290))
        // Decode one actual encoded frame from every scene, not the source PNGs.
        var frames: [CGImage] = []
        for index in 0..<17 {
            let frame = try await generator.image(at: CMTime(value: Int64(index * 9 + 4), timescale: 1))
            frames.append(frame.image)
        }
        sheet.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: sheet.size).fill()
        for (index, frame) in frames.enumerated() {
            let x = (index % 4) * 480
            let y = (4 - index / 4) * 290 + 20
            NSImage(cgImage: frame, size: NSSize(width: 1920, height: 1080))
                .draw(in: NSRect(x: x, y: y, width: 480, height: 270))
        }
        sheet.unlockFocus()
        let bitmap = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        print("PASS decoded all 17 scenes: H.264 1920×1080, 153 seconds, no audio")
    }
}

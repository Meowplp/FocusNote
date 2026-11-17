import Foundation
import Vision

// Read the actual PNGs, independently of scaled image previews. The snapshot
// fixture uses a 40-minute task, pauses after 62 seconds, and then visits breaks.
let directory = CommandLine.arguments.dropFirst().first ?? "/tmp/FocusNote-shots"
let fixtures = [
    ("ready", "40:00"), ("auto", "40:00"), ("running", "38:58"),
    ("paused", "38:58"), ("minimum", "38:58"), ("expanded", "38:58"),
    ("short-break", "10:00"), ("long-break", "20:00"),
    ("finished", "Alldone"), ("finished-minimum", "Alldone"),
]
var failures = 0
for (state, expected) in fixtures {
    for mode in ["light", "dark"] {
        let name = "timer-\(state)-\(mode).png"
        do {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(url: URL(fileURLWithPath: directory).appendingPathComponent(name)).perform([request])
            let text = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
            let found = text.contains { $0.filter { !$0.isWhitespace } == expected }
            if found { print("PASS \(name): \(expected)") }
            else {
                failures += 1
                print("FAIL \(name): expected \(expected); recognized \(text)")
            }
        } catch {
            failures += 1
            print("FAIL \(name): \(error.localizedDescription)")
        }
    }
}
for (state, expected) in [("task-progress", "1of5"), ("task-auto-completed", "5of5"), ("task-returned", "5of5")] {
    for mode in ["light", "dark"] {
        let name = "\(state)-\(mode).png"
        let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { continue }
        do {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(url: url).perform([request])
            let text = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
            if text.contains(where: { $0.filter { !$0.isWhitespace }.contains(expected) }) {
                print("PASS \(name): progress \(expected)")
            } else {
                failures += 1
                print("FAIL \(name): expected progress \(expected); recognized \(text)")
            }
        } catch {
            failures += 1
            print("FAIL \(name): \(error.localizedDescription)")
        }
    }
}
exit(failures == 0 ? 0 : 1)

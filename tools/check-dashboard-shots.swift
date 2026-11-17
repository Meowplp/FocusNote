import Foundation
import Vision
import AppKit
import ImageIO

let directory = CommandLine.arguments.dropFirst().first ?? "/tmp/FocusNote-shots"
let fixtures: [(String, [String])] = [
    ("analytics-dashboard", ["Analytics", "Streaks", "20 days", "Plan consistency", "Last 52 weeks"]),
    ("analytics-chart", ["Planned vs actual", "Hours", "Mon", "Sun", "Average planned", "Average actual"]),
    ("analytics-previous-week", ["Planned vs actual", "Average planned", "Average actual", "all 7 calendar days"]),
    ("analytics-empty", ["Analytics", "Streaks", "Plan consistency"]),
    ("history", ["History", "Your lists", "Pomodoros"]),
    ("history-detail", ["Read-only", "Copy Unfinished Tasks to Today", "Copy Unchecked Notes to Today", "Session details"]),
]
func normalize(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
func chartHasVisibleBars(_ name: String) throws -> Bool {
    let root = URL(fileURLWithPath: directory)
    let json = try Data(contentsOf: root.appendingPathComponent(name.replacingOccurrences(of: ".png", with: "-layout.json")))
    let object = try JSONSerialization.jsonObject(with: json) as? [String: Any]
    guard let frames = object?["probes"] as? [[String: Any]],
          let frame = frames.first(where: { ($0["name"] as? String) == "analyticsWeeklyChart" }),
          let x = frame["x"] as? Double, let y = frame["y"] as? Double,
          let width = frame["width"] as? Double, let height = frame["height"] as? Double,
          let window = object?["window"] as? [String: Double],
          let bitmap = NSBitmapImageRep(data: try Data(contentsOf: root.appendingPathComponent(name))) else { return false }
    let scale = Double(bitmap.pixelsWide) / (window["width"] ?? Double(bitmap.pixelsWide))
    guard let background = bitmap.colorAt(x: Int((x + 20) * scale), y: max(0, Int((y + 96) * scale)))?.usingColorSpace(.deviceRGB) else { return false }
    var columnsWithBars = 0
    for column in stride(from: max(0, Int((x + 16) * scale)), to: min(bitmap.pixelsWide, Int((x + width - 32) * scale)), by: 2) {
        var run = 0
        var longest = 0
        for row in stride(from: max(0, Int((y + 96) * scale)), to: min(bitmap.pixelsHigh, Int((y + min(height - 130, 300)) * scale)), by: 1) {
            guard let color = bitmap.colorAt(x: column, y: row)?.usingColorSpace(.deviceRGB) else { continue }
            let difference = max(abs(color.redComponent - background.redComponent),
                                 abs(color.greenComponent - background.greenComponent),
                                 abs(color.blueComponent - background.blueComponent))
            run = difference > 0.2 ? run + 1 : 0
            longest = max(longest, run)
        }
        if longest > Int(12 * scale) { columnsWithBars += 1 }
    }
    return columnsWithBars >= 5
}
var failures = 0
for (page, terms) in fixtures {
    for mode in ["light", "dark"] {
        let name = "\(page)-\(mode).png"
        do {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(url: URL(fileURLWithPath: directory).appendingPathComponent(name)).perform([request])
            var text = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ") ?? ""
            if page == "analytics-chart" {
                // Vision's standard pass does not read the rotated Y-axis title.
                for orientation in [CGImagePropertyOrientation.left, .right] {
                    let rotated = VNRecognizeTextRequest()
                    rotated.recognitionLevel = .accurate
                    try VNImageRequestHandler(url: URL(fileURLWithPath: directory).appendingPathComponent(name),
                                              orientation: orientation).perform([rotated])
                    text += " " + (rotated.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ") ?? "")
                }
            }
            // Long dashboards intentionally scroll; inspect the captured bottom too.
            let details = URL(fileURLWithPath: directory).appendingPathComponent("\(page)-details-\(mode).png")
            if FileManager.default.fileExists(atPath: details.path) {
                let extra = VNRecognizeTextRequest()
                extra.recognitionLevel = .accurate
                try VNImageRequestHandler(url: details).perform([extra])
                text += " " + (extra.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ") ?? "")
            }
            let missing = terms.filter { !normalize(text).contains(normalize($0)) }
            if missing.isEmpty { print("PASS \(name): dashboard content") }
            else { failures += 1; print("FAIL \(name): missing \(missing); recognized \(text)") }
            if page == "analytics-chart" {
                if try chartHasVisibleBars(name) { print("PASS \(name): weekly bars are visibly drawn") }
                else { failures += 1; print("FAIL \(name): expected visible weekly bars inside the chart") }
            }
        } catch { failures += 1; print("FAIL \(name): \(error)") }
    }
}
exit(failures == 0 ? 0 : 1)

import Foundation

/// One group of three clear, harmonically rich beeps. Output only; no microphone.
public struct AlarmTone: Sendable {
    public let frequency: Double
    public let sampleRate = 44_100
    public let beepsPerGroup = 3
    public let groups = 1
    public let beepSeconds = 0.18
    public let gapSeconds = 0.12
    public let groupGapSeconds = 0.4
    public init(frequency: Double) { self.frequency = frequency }

    public var groupSeconds: Double {
        Double(beepsPerGroup) * beepSeconds + Double(beepsPerGroup - 1) * gapSeconds
    }
    public var duration: Double { Double(groups) * groupSeconds + Double(groups - 1) * groupGapSeconds }

    public func samples() -> [Int16] {
        var result = [Int16](repeating: 0, count: Int(duration * Double(sampleRate)))
        for group in 0..<groups {
            for beep in 0..<beepsPerGroup {
                let startTime = Double(group) * (groupSeconds + groupGapSeconds) + Double(beep) * (beepSeconds + gapSeconds)
                let start = Int(startTime * Double(sampleRate))
                let length = Int(beepSeconds * Double(sampleRate))
                for index in 0..<length where start + index < result.count {
                    let time = Double(index) / Double(sampleRate)
                    let envelope = max(0, min(1, time / 0.005, (beepSeconds - time) / 0.008))
                    let phase = 2 * Double.pi * frequency * time
                    let tone = tanh(2.5 * sin(phase))
                    result[start + index] = Int16((tone * envelope * 0.9 * Double(Int16.max)).rounded())
                }
            }
        }
        return result
    }

    public func waveData() -> Data {
        let pcm = samples()
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func number<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        text("RIFF"); number(UInt32(36 + pcm.count * 2)); text("WAVE")
        text("fmt "); number(UInt32(16)); number(UInt16(1)); number(UInt16(1))
        number(UInt32(sampleRate)); number(UInt32(sampleRate * 2))
        number(UInt16(2)); number(UInt16(16)); text("data"); number(UInt32(pcm.count * 2))
        for sample in pcm { number(sample) }
        return data
    }
}

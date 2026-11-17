import Foundation

/// An original short, bright message-notification ding, not a copied recording.
public struct MessageChime: Sendable {
    public let sampleRate = 44_100
    public let duration = 0.9
    public init() {}

    public func samples() -> [Int16] {
        var mixed = [Double](repeating: 0, count: Int(duration * Double(sampleRate)))
        for sample in mixed.indices {
            let time = Double(sample) / Double(sampleRate)
            let attack = min(1, time / 0.003)
            let phase = 2 * Double.pi * 1_567.98 * time
            let bell = 0.68 * sin(phase) * exp(-time / 0.17)
                + 0.18 * sin(phase * 2.004) * exp(-time / 0.09)
                + 0.08 * sin(phase * 3.01) * exp(-time / 0.055)
                + 0.18 * sin(2 * Double.pi * 2_093 * time) * exp(-time / 0.13)
            mixed[sample] = attack * bell
        }
        let peak = mixed.reduce(0) { max($0, abs($1)) }
        let gain = peak > 0 ? 0.82 / peak : 0
        return mixed.enumerated().map { index, sample in
            let remaining = duration - Double(index) / Double(sampleRate)
            let release = min(1, remaining / 0.15)
            return Int16((sample * gain * release * Double(Int16.max)).rounded())
        }
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

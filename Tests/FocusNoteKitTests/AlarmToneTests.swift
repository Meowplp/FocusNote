import Foundation
import Testing
@testable import FocusNoteKit

@Test("Alarm plays one three-beep burst with silent gaps and no repeats")
func alarmSequence() {
    let alarm = AlarmTone(frequency: 980)
    let samples = alarm.samples()
    var bursts = 0
    var inBurst = false
    var silent = 0
    for sample in samples {
        if abs(Int(sample)) > 100 {
            if !inBurst { bursts += 1; inBurst = true }
            silent = 0
        } else {
            silent += 1
            // Ignore the waveform's ordinary zero crossings.
            if silent > alarm.sampleRate / 100 { inBurst = false }
        }
    }
    #expect(bursts == 3)
    #expect(alarm.groups == 1)
    #expect(alarm.duration > 0.5 && alarm.duration < 1)
    #expect(samples.count == Int(alarm.duration * Double(alarm.sampleRate)))
}

@Test("Alarm is strong without clipping and has click-free edges")
func alarmLevel() {
    let alarm = AlarmTone(frequency: 980)
    let samples = alarm.samples()
    let peak = samples.map { abs(Int($0)) }.max()!
    #expect(peak > Int(Double(Int16.max) * 0.85))
    #expect(peak < Int(Int16.max))
    #expect(samples.first == 0)
    let rms = sqrt(samples.reduce(0.0) { $0 + pow(Double($1) / Double(Int16.max), 2) } / Double(samples.count))
    #expect(rms > 0.4)
}

@Test("Generated alarm is a valid mono 16-bit PCM WAV")
func alarmWaveFormat() {
    let alarm = AlarmTone(frequency: 740)
    let data = alarm.waveData()
    #expect(String(data: data.prefix(4), encoding: .ascii) == "RIFF")
    #expect(String(data: data[8..<12], encoding: .ascii) == "WAVE")
    #expect(String(data: data[36..<40], encoding: .ascii) == "data")
    #expect(data.count == 44 + alarm.samples().count * 2)
    #expect(data[22] == 1 && data[34] == 16)
}

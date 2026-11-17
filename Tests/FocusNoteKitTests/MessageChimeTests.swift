import Foundation
import Testing
@testable import FocusNoteKit

@Test("Message notification is a short distinct ding, not an alarm")
func messageChimeCharacter() {
    let tone = MessageChime()
    #expect(tone.duration > 0.5 && tone.duration < 1)
    #expect(tone.waveData() != AlarmTone(frequency: 980).waveData())
}

@Test("Message ding is normalized, audible, unclipped, and fades out")
func messageChimeLevel() {
    let tone = MessageChime()
    let samples = tone.samples()
    let peak = samples.map { abs(Int($0)) }.max()!
    #expect(peak > Int(Double(Int16.max) * 0.8))
    #expect(peak < Int(Double(Int16.max) * 0.83))
    #expect(samples.first == 0)
    let tail = samples.suffix(tone.sampleRate / 10).map { abs(Int($0)) }.max()!
    #expect(tail < Int(Double(Int16.max) * 0.01))
    #expect(abs(Int(samples.last!)) < 5)
}

@Test("Message notification WAV contains the expected mono PCM duration")
func messageChimeWaveFormat() {
    let tone = MessageChime()
    let data = tone.waveData()
    #expect(String(data: data.prefix(4), encoding: .ascii) == "RIFF")
    #expect(String(data: data[8..<12], encoding: .ascii) == "WAVE")
    #expect(data.count == 44 + Int(tone.duration * Double(tone.sampleRate)) * 2)
    #expect(data[22] == 1 && data[34] == 16)
}

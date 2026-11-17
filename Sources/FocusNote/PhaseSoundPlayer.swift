import Foundation
import AVFAudio
import FocusNoteKit
import os

enum PhaseSoundCue: String, Sendable {
    case work, rest

    nonisolated var isAlarm: Bool { self == .work }
    nonisolated var waveData: Data {
        isAlarm ? AlarmTone(frequency: 980).waveData() : MessageChime().waveData()
    }
}

/// Enqueue on the UI actor in event order; all audio-service work runs elsewhere.
final class PhaseSoundPlayer {
    private var pending: [PhaseSoundCue] = []
    private var draining = false
    private var drainTask: Task<Void, Never>?
    private var generation = UUID()
    private let output = PhaseSoundOutput()

    func enqueue(_ cue: PhaseSoundCue) {
        pending.append(cue)
        guard !draining else { return }
        draining = true
        drainTask = Task { @MainActor in
            while !pending.isEmpty {
                let cue = pending.removeFirst()
                await output.play(cue, generation: generation)
            }
            draining = false
        }
    }

    func prepare(_ cue: PhaseSoundCue) async -> Bool {
        await output.prepare(cue)
    }

    var preparationWasOffMainThread: Bool {
        get async { await output.preparationWasOffMainThread }
    }

    func stop() {
        let stoppedGeneration = generation
        generation = UUID()
        pending.removeAll()
        Task { await output.stop(generation: stoppedGeneration) }
    }

    func waitUntilFinished() async { await drainTask?.value }

    var playbackDiagnostics: (completed: Int, offMain: Bool) {
        get async { await output.diagnostics }
    }
}

private actor PhaseSoundOutput {
    private var sounds: [String: AVAudioPlayer] = [:]
    private var completion: AlarmPlaybackCompletion?
    private var currentPlayer: AVAudioPlayer?
    private var currentGeneration: UUID?
    private(set) var preparationWasOffMainThread = false
    private var completed = 0
    private var playbackOffMain = false
    var diagnostics: (completed: Int, offMain: Bool) { (completed, playbackOffMain) }

    func prepare(_ cue: PhaseSoundCue) -> Bool { player(for: cue) != nil }

    func play(_ cue: PhaseSoundCue, generation: UUID) async {
        guard let player = player(for: cue) else { return }
        recordPlaybackThread()
        currentPlayer = player
        currentGeneration = generation
        let succeeded = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let completion = AlarmPlaybackCompletion(continuation)
            self.completion = completion
            player.delegate = completion
            player.currentTime = 0
            if !player.play() { completion.finish(success: false) }
        }
        if succeeded { completed += 1 }
        player.delegate = nil
        completion = nil
        currentPlayer = nil
        currentGeneration = nil
    }

    func stop(generation: UUID) {
        // A delayed mute must not stop a newly requested preview after unmuting.
        guard currentGeneration == generation else { return }
        currentPlayer?.stop()
        completion?.finish(success: false)
    }

    private func recordPlaybackThread() { playbackOffMain = !Thread.isMainThread }

    private func player(for cue: PhaseSoundCue) -> AVAudioPlayer? {
        if let player = sounds[cue.rawValue] { return player }
        preparationWasOffMainThread = !Thread.isMainThread
        guard let player = try? AVAudioPlayer(data: cue.waveData) else { return nil }
        // Use the normal output path at full application gain, not the quieter
        // macOS alert-sound level. Never change the user's system volume.
        player.volume = 1
        player.numberOfLoops = 0
        guard player.prepareToPlay() else { return nil }
        sounds[cue.rawValue] = player
        return player
    }
}

/// Audio callbacks may arrive on any queue; resume the FIFO's continuation once.
private final class AlarmPlaybackCompletion: NSObject, AVAudioPlayerDelegate {
    private nonisolated let continuation: OSAllocatedUnfairLock<CheckedContinuation<Bool, Never>?>

    nonisolated init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = OSAllocatedUnfairLock(initialState: continuation)
        super.init()
    }

    nonisolated func finish(success: Bool) {
        let pending = continuation.withLock { value in
            let pending = value
            value = nil
            return pending
        }
        pending?.resume(returning: success)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { finish(success: flag) }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) { finish(success: false) }
}

# Fix log

## Lazy month-calendar replacement

The first full snapshot traversal reproduced an index-out-of-range crash when
switching from Month to Day. Old lazy grid cells captured integer indices but read
the new period's dynamically computed dates array. Freeze the dates array and its
offset together before constructing cells; period/date navigation also resets
scroll identity. The full snapshot traversal and a live self-test now exercise
month/day/week replacement.

Rule: lazy cells must index the immutable collection they were created from, never
a recomputed collection whose shape changes with global selection.

## Main-window captures looked inactive

Direct executable launches on this macOS left main-window screenshots without
foreground activation rights. Launching the isolated snapshot copy through
LaunchServices (`open -n -W --env …`) restored active title bars and controls.

Rule: validate active-window snapshots; do not change UI colors to compensate for
an inactive capture.

## Repeated Screen Recording prompts

The user had already granted FocusNote screen/audio recording access. Development
snapshots nevertheless invoked `/usr/sbin/screencapture` from an ad-hoc-signed app,
whose identity changes across builds. Permission toggles cannot provide a stable
grant to every rebuilt identity.

Remove that subprocess entirely. `OwnWindowSnapshot` caches only the process's own
view hierarchy into a PNG, without screen/audio APIs or permission checks. The
snapshot launcher uses a separately named FocusNote Preview bundle and never resets
the real app's saved state. A source audit and renderer self-check prevent regression.
Snapshot sweeps are guarded against re-entry after a SwiftUI window/task remount.

Rule: a checklist/timer must not request screen/audio recording merely to test its
own UI; never fix this by repeatedly resetting TCC or requesting broader access.

## Phase cues too easy to miss over videos

Single system chimes remained unobtrusive, and system-alert playback can follow the
Mac's quieter alert-volume setting. Replace them with generated nine-beep alarm
bursts (~3.14 seconds), distinct work/rest pitches, and full application gain through
normal output. AVAudioPlayer preparation/playback stays on an actor; thread-safe,
one-shot delegate completion preserves the FIFO. A generation token ensures a late
mute cannot cancel a newly requested preview. No global volume or recording grants
are changed.

Unit checks validate nine bursts, silence gaps, nonclipping strong amplitude, and
PCM headers. An opt-in live test completed both sequences through real delegates.
Self-tests now use a uniquely identified Preview bundle instead of sharing the
personal app's saved window state, which could otherwise prevent a test window opening.

Rule: test the actual playback path, not just available sound assets; audible alarms
must not block countdown rendering or require screen/microphone/audio-recording access.

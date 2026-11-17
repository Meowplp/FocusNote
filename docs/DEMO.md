# Feature walkthrough

The captioned 1080p MP4 in `media/focusnote-demo.mp4` uses fictional sample tasks
and renders of FocusNote's own views. It is a **scripted still-image walkthrough**,
not a live recording. Timer states are advanced for demonstration.
There is no narration, music, microphone input, or screen capture.

The 2-minute-33-second walkthrough covers Today, reminders, task plans, floating
timer sizing, pause/resume, Auto, short and long breaks, task completion and
return, daily rollover, History, Analytics, timer settings, and appearance.

## Recreate

```sh
./build.sh
tools/snap.sh
# Set shots to the private directory printed by the command above.
swiftc -parse-as-library tools/make-demo.swift -o "$shots/make-demo"
"$shots/make-demo" "$shots" "$shots/focusnote-demo.mp4"
```

The encoder uses native AVFoundation, not ffmpeg. On a newer SDK, AVFoundation
may report deprecation warnings for APIs retained to support macOS 26.
Do not run `build.sh --open` during an active personal timer.

The movie shows native controls rendered into image caches; system glass can
differ from its on-screen compositor appearance. The Settings screen offers
sound previews, but the movie intentionally has no audio track.

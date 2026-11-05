# Performance beat number — 2026-11-05

Build: 1.0.2 (12).

## Approved interaction

- C direction: current pulse number dominates the same recessed display material as the home instrument. Tempo, meter and real subdivision notation are secondary tappable metadata above it.
- Stopped setup shows a dash, not a false running beat; Play starts the existing audio clock. While playing, the number follows that clock's pulse and the layout does not jump between strengths. Manual accented beats use the same rhythm strength as audio; metrical secondary accents use a lighter mark. Small double rings identify accented positions.
- Minus/Tap/Plus retain immediate adjustment, shared-song persistence and pedal-equivalent behavior. Existing live Meter/Division comparison remains open across repeated choices.
- The speaker button was removed from performance. General → Playback sound provides the existing session mute; returning to home while muted still exposes the restore-sound indicator.
- The next song is explicitly labelled. No display-style selector added.

## Verification

- iPhone 17 Pro simulator, iOS 26.5: 4 PerformanceTests and 4 PerformanceUITests passed in `/tmp/metronome-beat-number.xcresult`.
- Covered visual-only beat progression, consecutive tempo/song changes, boundaries, returning while still playing, General mute/home restore, shared songs, practice routes, and repeated live subdivision comparison.
- Inspected native Chinese light and English dark screenshots, including subdivision notation, next-song label, transport visibility and General sound control.
- Release device build/signing succeeded. User explicitly deferred installation until reconnecting the iPhone; no installation or physical pedal/lock-screen checks claimed.
- Startup path and audio engine were unchanged; no phone launch timing measured. This change was not a complete iPad or Dynamic Type layout audit.

- Additional Chinese performance run passed with an explicit first-beat wait and native accent screenshot (`/tmp/metronome-beat-number-accent.xcresult`).

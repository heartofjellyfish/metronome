# Performance view and reusable songs — 2026-11-05

Build: 1.0.2 (11). Implementation and simulator verification complete; phone installation blocked by unavailable device.

## Interaction decisions

- Setlist: stopped selection prepares a song without starting. During playback a different song applies its parameters and starts that song's bar; the list stays open. Selecting the same unchanged song is a no-op. Consecutive next/previous selections do not wrap; the list follows selection and transport stays fixed.
- Perform: entering/leaving preserves transport. Song name, BPM and numbered beat blocks dominate. The beat display reads the same SampleClock events as audio. Sound toggle changes mixer gain, without stopping/resetting the clock. In-session mute is visible and reversible on the home display after returning.
- Performance +/- and Tap save tempo to the song. Meter and Division pickers support stopped selection/return and live consecutive comparison. Editing a song uses a draft with Cancel/Save; shared edits are identified in the editor. Pedal tempo/next/previous commands use the same model.
- Song objects: canonical catalog + ordered IDs per setlist in one persisted archive. Legacy nested lists migrate without changing IDs/order. Removing a membership or deleting a setlist retains songs in the catalog. Add from Song library reuses identity; importing a preset creates a new song without practice effects. Duplicate membership in the same list is disabled.
- Practice entry: three routes with real configuration summaries and count-in. No transport, save button or haptics. Ramp, silent-bars and polyrhythm pages keep a fixed transport for in-place comparison. Haptics are under General in Settings.

## Boundaries

- Visual-only playback still relies on the existing audio clock and audio-session interruption policy; it does not bypass system phone-call/alarm priority.
- Physical pedal, headphone, background/lock-screen and real interruption checks remain deferred. Simulator tests are not those hardware checks.
- No new sounds or launch-time audio decoding added. Initial song-store reserialization is avoided.

## Verification

- iPhone 17 Pro simulator, iOS 26.5, Debug: 29 model/audio tests and 8 UI journeys passed (`/tmp/metronome-performance-final.xcresult`).
- After completing the SOUND translations, the Chinese performance journey was rerun and passed (`/tmp/metronome-performance-localized.xcresult`). All nine localization files passed plist validation.
- UI coverage: muted clock/beat motion, repeated tempo and song changes, first/last boundaries, chooser, draft cancellation, return with playback continuing, visible home mute recovery, shared song reuse/edit/removal, practice entry/detail transport, General haptics, repeated live division changes, light/dark and Chinese/English.
- Visually inspected the nine attached native screenshots. Fixed the editor's untranslated SOUND label. Test fixes made button identifiers unique across covered screens, selected hittable controls, and used a locale-independent Cancel identifier.
- Release iOS device build and signing succeeded. Attempted installation on the previously connected iPhone 14 Pro; CoreDevice reported no available matching device (error 1011). Build is **not installed**.
- No phone first-screen timing was measured in this run. Simulator tests do not establish the one-second iPhone launch requirement. Full iPad, large text and all-language layout checks were not repeated for this change.

## Remaining design judgment

Practice's entry page is a compact directory, so it has no Play/Save controls. Each specific exercise keeps its own fixed start/stop button for immediate comparison while changing parameters. Setlists keep transport for auditioning order; the separate performance screen enlarges the current song and visual beat cue for stage use. Shared edits update the same song in every setlist, with a short notice in the editor when relevant.

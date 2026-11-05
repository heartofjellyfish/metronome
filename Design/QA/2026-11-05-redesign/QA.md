# Navigation, division and setlist redesign — 2026-11-05

Version: 1.0.2 (10). Native SwiftUI implementation; attached images are actual simulator screenshots, not mockups.

## Delivered behavior

- Settings: current sound first, then Practice/Presets, then Live Mode with Setlists/Pedal. Chinese headings are localized. Meter and Division remain on the instrument.
- Division: all eight even subdivisions visible; selected category uses charcoal hardware keys. Pattern families use music notation and separate audition buttons. Editing is nested within Patterns, with rests and Swing.
- Stopped selection applies and returns to the instrument. During playback, consecutive choices apply immediately and remain open. Audition does not change the selected rhythm. Stopped editor changes remain drafts until confirmed.
- Setlists contain songs in a recessed container; songs keep BPM, meter, subdivision and sound. Rename, reorder, delete, play and next/previous are supported. Songs can be imported from presets or added to a setlist from the preset menu.
- Imports copy musical settings and omit practice effects. Original song/practice presets remain independent. Song editing has Cancel/Save and does not expose ramp/gap practice controls.
- Polyrhythm has its own Practice page, with independent wood/bell voices. Division settings remain available when polyrhythm is switched off.
- Saved pedal bindings remain visible and green; learning uses a flashing red lamp and depressed key. Saved bindings do not imply a live Bluetooth connection. Identifiable MIDI sources have named profiles; generic HID input uses a saved/manual profile because iOS does not expose a reliable per-pedal identity through key events.

## Acceptance evidence

Simulator: iPhone 17 Pro, iOS 26.5, Debug, Xcode command-line tests.

- 25 unit tests passed: clock behavior, interruption catch-up, Swing, polyrhythm voices, MIDI source/profile changes, binding collisions, saved-data migration, preset/setlist isolation and playback preparation.
- Seven targeted UI journeys passed across the final runs: four RedesignUITests; repeated live preset comparison and unique sound library; complete setlist creation/edit/reorder/reopen/delete; independent practice preset import and editing.
- Inspected light/dark and Chinese/English screenshots for notation, selection contrast, key proportions, lamp position, editor display alignment and song-list containment.
- UI testing found and fixed undersized key backgrounds, blank-center hit areas and BPM editing that could accidentally append digits. A final test expectation was corrected for direct-to-setlist launch, which returns directly to the instrument rather than Settings.
- Latest setlist CRUD rerun: `/tmp/metronome-redesign-setlist-final.xcresult`, one test, zero failures. Other final UI evidence: `/tmp/metronome-redesign-acceptance.xcresult` (five passing journeys; obsolete close-settings expectation fixed in the separate rerun). Earlier independent preset journey: `/tmp/metronome-redesign-interactions.xcresult`.
- Unit evidence: `/tmp/metronome-redesign-finalcheck.xcresult`, 25 unit tests with zero failures. This bundle also contains an earlier UI failure resolved in subsequent runs; it is not an all-green full-suite claim.
- `git diff --check` passed.

## Device installation and limits

- Release build succeeded and 1.0.2 (10) installed successfully on the connected iPhone 14 Pro, iOS 27.0.1. Installation result: `/tmp/metronome-redesign-installed.json`.
- Physical first-screen performance test stopped at “Unlock iPhone to Continue”. No valid phone launch measurement was obtained, so the under-one-second requirement remains unverified for this build. Simulator playback-preparation timings are not phone startup timings.
- Physical pedal compatibility/latency, headphones, background/lock-screen playback and real calls/alarms were not tested this round. Automated source/binding/clock tests do not substitute for those checks.
- Large Dynamic Type and the complete iPad/language matrix were not reviewed in this round. Current screenshots cover the targeted phone layouts; no claim of perfect UX across every environment.
- Deliberate interaction choice: regular and advanced even subdivisions are all exposed; pattern families can scroll. A speaker auditions, while a notation card applies. Song imports intentionally omit practice effects, with a notice for affected presets.
- A separate silent-bar practice app is recorded as a future idea only. No new app, pricing or commercial change was made.

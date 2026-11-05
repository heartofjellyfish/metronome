# Settings, independent presets, and performance tools — review

Build: 1.0.2 (8), 2026-11-04. This is an implementation review and heuristic evaluation from five perspectives, not a study with five recruited users.

## Result

Settings now groups Rhythm (meter, division, practice, presets), Sound, and Live Mode (setlists, pedal, collapsible preparation). Standalone presets are independent of setlists. Practice settings can be saved directly; setlists can import independent copies. Existing saved data is retained.

## Findings and fixes

| Perspective | Problem found | Change and evidence |
| --- | --- | --- |
| UI/UX designer | More mixed practice, storage and live performance. Fixed whole-page scaling shrank controls on small screens. | Separate task groups; native-sized controls and scrolling. Ivory/graphite materials reuse the existing hardware surfaces. Light/dark and localized screenshots inspected. |
| Product owner | Presets had effectively been replaced by setlists. A single practice should not require a folder. | Independent preset entry and Save as preset from Practice. Import creates a new identity and copies the full rhythm, including ramp, rests, sound and gap training. Unit and UI persistence checks pass. |
| Picky customer | French preset label broke mid-word; large German binding captions hyphenated; mostly empty panels occupied most of the screen. | Reduced icon footprint, single-line navigation labels, full-width binding keys at accessibility sizes, content-sized preset/setlist panels. Corrected screenshots inspected after a second small-screen run. |
| Drummer | Tapping a song while editing could change playback. Saving a snapshot cleared the live queue. Renaming an active ramp song could disable its ramp. | Edit-mode rows edit; snapshot saving preserves the active setlist/song; renaming preserves the ramp. Explicit BPM changes disable the ramp with an explanatory hint. Model and playing UI journeys pass. |
| First-time user | Current non-recommended sound was hard to identify; tiny dynamics keys; preset row hid practice details; inactive save controls looked active. | Current sound remains visible beside All sounds; dynamics hit targets are 44 pt; saved rows show BPM/range and silent bars; unavailable saves are dimmed. Advanced subdivision pulses use two rows when needed to retain usable targets. |

Also added missing tuplet grouping marks to advanced pattern diagrams. Pattern timing and Stage Click signal tests were rerun. These checks do not establish how the click cuts through a real drum kit.

## Interaction contract

- Stopped setup: choosing a preset/song applies it and closes its picker; saving a practice has an explicit return to Practice.
- Playing: meter, division, preset and song comparisons apply and remain open. Second and third choices, selection marks, closing/reopening and ongoing playback are checked.
- Audition: sound choices remain open in both stopped and playing states. Current sound survives closing and reopening.
- Saving/importing is separate from choosing a playback item. Import leaves the original preset intact; later edits or deletion of one copy do not change the other.
- Pedal learning stays directly accessible without an unverifiable connection gate. Saved assignment and confirmed Bluetooth connection remain different states.

## Verification rounds

1. Structural/code review and initial native screenshots. Fixed grouping, preset independence, edit-mode selection and copy semantics.
2. iPhone 17 Pro Max simulator, iOS 26.3: 20 logic tests and 9 UI tests passed. UI test loops include en, zh-Hans, zh-Hant, ja, ko, de, fr, es, pt-BR; English/Chinese/German light/dark/preparation states. Reviewed actual screenshots.
3. Focused regression after queue-preservation and typography changes: 20 logic tests plus 4 UI journeys passed, including legacy live preset comparison and current-sound visibility.
4. iPhone SE (3rd generation) simulator, iOS 18.2: 3 UI journeys passed (small-screen/large-text controls, standalone practice/import, setlist CRUD/reordering). Screenshot inspection found the French and large German wrapping defects and an ineffective first attempt at panel sizing.
5. Fixed those visual defects and repeated the two affected small-screen journeys: both passed; corrected screenshots inspected. Final large-screen save/import/edit journey also captured for comparison.

Across the rounds, 20 distinct logic tests and 12 distinct UI tests ran successfully. Repeated tests are not counted as new coverage. The full historical UI suite was not rerun. No new audio decoding or catalog work was added to launch.

Local evidence:

- `/tmp/metronome-organization-round2.log`
- `/tmp/metronome-organization-round3.log`
- `/tmp/metronome-organization-compact.log`
- `/tmp/metronome-organization-polish.log`
- `/tmp/metronome-organization-final-preview.log`
- Corresponding xcresults are in `/tmp/metronome-live-build/Logs/Test/`.

## Physical device / remaining limits

The final build was successfully built and installed on the connected iPhone 14 Pro at 23:12. Installation receipt bundle identifier: `com.heartofjellyfish.themetronome`; container ID: `63BE440C-FD90-41A0-B71E-D11BD4811D8B`.

This round's physical launch benchmark could not start because the phone was locked; the waiting test was cancelled. Do not report simulator timing as physical timing or reuse the previous build's measurement as a new measurement.

Actual pedal compatibility/latency, background and lock-screen controls, real calls/alarms, and audibility through stage headphones remain physical validation tasks. Notification handling and timing tests cover software behavior only. iPad layouts were not newly exercised in this round. The interface's custom instrument typography does not yet scale every label to accessibility text sizes; the pedal binding flow was specifically checked and improved.

The layout/wording decisions are heuristic judgments, not proof of intuitive use by new users. A short first-use session with the drummer is the next external validation. No known failure remains in the tested journeys; this is not a guarantee that every possible issue is eliminated.

TestFlight was not changed by this work.

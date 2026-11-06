# Build 20 — Song library hierarchy and compact live notes

- Version: 1.0.2 (20).
- Simulator: iPhone 14 Pro, iOS 26.5, dedicated Metronome Division QA device.
- Passed 12 PerformanceTests and 4 focused PerformanceUITests; result bundle `/tmp/metronome-library-layout.xcresult`.
- Tested library create/search/edit/delete/cancel, add-to-setlist, multiple membership labels, drag reorder persistence, and catalog order independent from setlist performance order.
- Tested notes opening/closing while playing, unchanged beat display height, notes button aligned with metadata, switching songs with/without notes, and explicit exit to instrument without stopping playback.
- Inspected actual screenshots: settings icon, library, multiple labels, expanded row actions, delete confirmation, collapsed live notes and expanded notes.
- Release device build succeeded and installed on the connected iPhone 14 Pro using devicectl. Automatic launch was denied because the phone was locked; manual opening after unlock is still required.
- Physical background, lock-screen, headphone and pedal checks were not performed; this change does not alter their implementation. Startup timing was not remeasured for this UI-only change.

Library information is static; one physical action key reveals Edit / Add to setlist / Delete for that row. Reorder is separate from each setlist's running order. Membership labels are generated from actual setlists, not a separate manual tag system.

Live View puts total song count next to the setlist name, ordinal next to the song title, and Notes beside tempo/meter/subdivision. Notes no longer use space below the beat display.

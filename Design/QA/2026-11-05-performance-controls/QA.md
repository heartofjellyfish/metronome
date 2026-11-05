# Performance controls — 2026-11-05

Build: 1.0.2 (13).

## Approved layout and interaction

- Tempo decrease/value/increase, meter and subdivision stay on one row. Values look like controls; opening a picker retains the established behavior.
- Previous and next share one row. Previous is a compact icon key. The entire next-song card is a button with the destination title and tempo. At list boundaries the corresponding button is disabled, with no wrapping.
- Tap tempo and the larger play/stop key share the bottom row. Their positions do not change during playback. The current beat remains the dominant recessed display.
- Stopped setup: changing songs does not start playback; Tap updates tempo without starting playback. Active playback: song changes keep playback active and tempo changes apply immediately. Repeated comparisons: existing live meter/division pickers stay open and reflect the current selection; explicit close remains available.
- Removed the ambiguous list-position fraction from the header. The setlist chooser and Edit now use the shared physical-key surface.

## Verification

- iPhone 17 Pro simulator, iOS 26.5: initial run passed four PerformanceTests and three PerformanceUITests. Coverage includes repeated forward/back navigation, boundaries, stopped-vs-playing behavior, tempo adjustment, picker selection persistence and control-row alignment.
- Screenshot inspection caught clipped beat markers and cramped setlist-title padding. Both were corrected before the final run.
- Audio engine and startup path are unchanged; no new physical startup measurement, pedal, background or lock-screen claim.
- Final three UI tests passed after the corrections (`/tmp/metronome-performance-controls-final.xcresult`). Inspected the final Chinese light and English dark screenshots: display border/beat markers fully visible, header padding restored, both bottom rows and the parameter row remain single-line.
- Signed Release iPhone build succeeded. Device discovery still reports the iPhone 14 Pro unavailable, so installation is pending the user's connection; no successful installation claimed.
- Layout was checked on iPhone 17 Pro simulator at default text size; this change is not a complete iPad or Dynamic Type audit.

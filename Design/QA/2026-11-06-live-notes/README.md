# Live Mode navigation, song notes and library — 2026-11-06

Version: 1.0.2 (18).

- Settings exposes Setlists, Song library and Pedal as three independent illustrated buttons.
- Song library manages shared songs directly; list membership and song content remain distinct.
- Start from first song explicitly starts playback; subsequent song changes are manual. No song duration, bar-count requirement or automatic progression.
- Live View identifies song position, provides a separate close-to-instrument action and optional expandable notes. Closing navigation preserves playback.
- Duplicate setlist copies ordering and song references without changing the active song.

## Validation

- 11 PerformanceTests passed, covering catalog CRUD, shared membership, migration, playback and notes. The updated notes/duplicate test passed again after the duplicate feature was added.
- Two final UI journeys passed: direct song-library entry/edit/back/close; first-song start, notes edit/expand, next/previous, return to instrument without stopping, stopped song selection, duplicate setlist.
- Release device build succeeded. Installed successfully on the connected iPhone 14 Pro. Automatic launch was blocked by the phone being locked; unlock and open the installed app manually.
- Screenshots captured on the dedicated iPhone 14 Pro simulator (iOS 26.5), inspected for hierarchy, alignment and clipping. Overview is a montage of actual screenshots.
- Physical pedal, audio interruption and lock-screen/background checks were not performed in this change. No phone startup timing was measured.
- Full-title expansion is implemented; unusually long text and larger accessibility text sizes have not received a dedicated screenshot pass.

# Live Mode navigation and protected performance controls

Version: 1.0.2 (17). Design proposal used built-in imagegen; prompt retained in `design-prompt.txt`. The screenshots in this folder are actual simulator captures, not the proposal.

## Interaction contract

| Entry / action | Stopped | Playing | Return / repeat |
| --- | --- | --- | --- |
| Settings → Setlists | All setlists | All setlists; playback unchanged | Always opens the root |
| Home recent caption | Most recently loaded list or presets | Same shortcut; playback unchanged | Browsing another list does not replace the caption |
| Open a setlist | Browse its songs | Browse without changing the current song | Back returns to all lists |
| Tap a song | Load it and open Live View, without autoplay | Load it and continue playback in Live View | Back returns to that song list |
| Live View parameters | BPM, meter and subdivision are plain information | Same; accidental taps cannot edit | Edit opens a draft; Cancel discards, Save applies |
| Reorder | Drag the handle; the whole song group moves | Same; active song identity and clock remain stable | Order persists; VoiceOver move actions are available |
| Add songs | New song / Choose saved songs / Import from presets | Same; importing does not load the song | Shared songs retain identity; presets import as copies |

## Validation

- 10 PerformanceTests passed: inactive-list changes, shared songs, deletion, reordering and bounds, persistence, recent preset identity, live transport and audio output.
- UI journeys cover dark-mode edit/cancel/save/reopen, stopped next/previous boundaries and control alignment, shared-song editing/removal/reuse, list rename and drag down/up, Settings root versus home recent shortcut, continuous visual-only playback and repeated song selection.
- Initial UI runs encountered simulator CoreAudio error 35 and lost accessibility/test-service connections. Those failures are retained in `/tmp/metronome-live-navigation-ui.xcresult` and `/tmp/metronome-live-navigation-retry.xcresult`; successful follow-up results are recorded separately. They are not represented as app passes.
- Final rerun: both recent-song/root navigation and visual-only continuous playback passed; ModelTests passed. All six selected UI journeys passed across the runs. A seventh settled-screen navigation journey also passed (`/tmp/metronome-live-navigation-screens.xcresult`). Final bundle: `/tmp/metronome-live-navigation-final.xcresult`.
- Release build succeeded. Installed on the connected iPhone 14 Pro and successfully launched using CoreDevice. Physical lock-screen/background/headphone tests remain deferred.

## Visual review

- Retains ivory hardware buttons, inset list tray and the existing LCD beat display.
- No duplicate Perform entry or browsing-page player. Song chevrons signal the transition into Live View.
- All parameters share one quiet row; song position stays beside the song name.
- Reorder uses one stable song group containing its card and edit controls, with a short animation; Reduce Motion disables the animation.
- Deliberate choice: Tap tempo remains a direct performance control. Saved song parameters otherwise require Edit.

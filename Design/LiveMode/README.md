# Live Mode · 1.0.2 (3)

Six learnable actions: next song, previous song, BPM +1, BPM −1, play/stop, tap tempo. Songs use the existing ordered saved presets; this is not a new playlist database. End-of-list navigation does not wrap. Loading a song while playing starts the selected rhythm; stopped navigation stays stopped. Learning consumes the first press, stays open, and supports another press to execute after binding. Cancel/close never changes an existing assignment. Rebinding a key removes its previous action to avoid collisions. Bindings persist locally. Text-field typing is excluded from keyboard routing.

## Protocol coverage, not certified hardware compatibility

No trustworthy unified sales ranking was found. These are representative products with manufacturer documentation, not a claim of sales rank or hardware-tested compatibility:

| Product family | Documented input | Implemented route | Validation still required |
| --- | --- | --- | --- |
| Coda STOMP | HID arrows, PageUp/Down, Space/Return | Keyboard learning, foreground only | Firmware, switch repeats, real pairing |
| PageFlip Firefly / Butterfly / Dragonfly | Keyboard emulation | Keyboard learning, foreground only | Model/firmware and configured keys |
| AirTurn BT500S / DUO family | Keyboard and MIDI modes; some models also media mode | Keyboard, CoreMIDI, system media commands | Exact model/mode, sleep/reconnect, background restart |
| Other standard MIDI pedals | Note on/off, CC, program change | CoreMIDI input with source/channel binding | Exact messages and device lifecycle |

Sources checked 2026-11-03:
- https://www.codamusictech.com/pages/stomp-manual
- https://www.codamusictech.com/blogs/news/will-stomp-work-with-my-app
- https://www.pageflip.com/products/firefly
- https://www.pageflip.com/pages/faq-pedals
- https://www.airturn.com/blogs/support/bt500s-2
- https://www.airturn.com/blogs/support/faq
- https://www.bhphotovideo.com/lit_files/961687.pdf (manufacturer manual)

Keyboard input is not a background/lock-screen control channel. iOS media controls retain paused Now Playing information; learned pedal playback uses a primary, nonmixable playback session. Another app taking over Now Playing, a force-quit, or device restart can require reopening the metronome. CoreMIDI receives from connected sources using Apple's Bluetooth MIDI picker; **long-idle background MIDI wake/restart remains unverified**. Do not market universal locked-screen support. There is no silent-audio keepalive or private HID API.

For MIDI CC use a momentary switch (pressed ≥64, released <64); Note On velocity 0 is release. Program Change is a discrete press. Running status survives MIDI packet boundaries; realtime bytes and SysEx are not learned. Input from a different MIDI source/channel cannot operate another device's binding. Keyboard key-up, MIDI release and repeated held keys do not toggle twice. 80 ms bounce protection still allows tapping at 300 BPM.

## Interruption policy

- Playback category supports silent-switch and background playback. Ordinary UI presentation does not call stop.
- Requests `setPrefersNoInterruptionsFromSystemAlerts(true)`; iOS still decides whether an interruption occurs.
- On interruption, stop the engine and snapshot its sample timeline. Resume only after an ended notification with `shouldResume` and preserved user intent.
- Advance the timeline silently across the missing duration, preserving count-in, ramp and gap progress. Do not replay missed clicks or restart beat one. Rescale phase if the output sample rate changes. This is an internal musical timeline, not synchronization to the live drummer or external clock.
- User stop during interruption cancels automatic recovery. Headphone removal also cancels it; never automatically continue through speaker.
- Media-service reset and unsupported output changes stop safely rather than claiming seamless recovery.
- Incoming calls (banner/full-screen, answered/declined), Siri, Clock alarms/timers, other media apps, Bluetooth earphones reconnecting, 10-minute locked playback and long paused restart require physical tests.
- Airplane/focus/silent modes do not turn off Clock alarms. System-owned interruptions cannot be guaranteed inaudible or bypassed.

## Verification

- Initial 8 simulator unit/audio tests passed; follow-up 10 tests (8 unit/audio + 2 UI journeys) passed on iPhone 17 Pro Max / iOS 26.3.1 simulator. English, Simplified Chinese and German screenshots inspected; all six rows remain visible; longer labels fit.
- New tests cover learning/cancel/rebind/held keys/debounce, MIDI parsing/source identity, six actions and preset boundaries, persisted bindings, interruption intent, headphone-loss cancellation, sample-rate conversion and 10-minute timeline equivalence including count-in/ramp/gap.
- Physical installation of 1.0.2 (3) succeeded on iPhone 14 Pro. The launch/background test was blocked by “Unlock iPhone to Continue” and canceled after waiting; no launch timing, physical background, pedal, call or alarm pass is claimed.
- Final MIDI Program Change parsing and off-render-thread catch-up refinements passed all 8 simulator unit/audio tests (2026-11-03, result Test-TheMetronome-2026.11.03_12-45-18--0800.xcresult). Standalone sample-clock/dial/meter tests also passed, including all 480 meter/mode/subdivision combinations. Native string validation covers 173 keys across nine languages; Bluetooth permission text is localized too.

This build is a test candidate, not submitted to App Review. Version 1.0.1 (2) remains the separately submitted localization update.

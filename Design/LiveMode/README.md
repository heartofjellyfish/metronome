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
- Physical installation of 1.0.2 (3) succeeded on iPhone 14 Pro. The initial launch/background attempt was blocked by the locked phone; the user subsequently unlocked it and a retry is running. Launch-to-responsive first frame measured 0.340 s average over five launches (0.326–0.355 s), iPhone 14 Pro, development Debug build, XCUITest instrumentation. This is not a Release cold-boot or headphone-latency measurement.
- Final MIDI Program Change parsing and off-render-thread catch-up refinements passed all 8 simulator unit/audio tests (2026-11-03, result Test-TheMetronome-2026.11.03_12-45-18--0800.xcresult). Standalone sample-clock/dial/meter tests also passed, including all 480 meter/mode/subdivision combinations. Native string validation covers 173 keys across nine languages; Bluetooth permission text is localized too.

The additional explicit media Play/Pause test passed: repeated Play stays playing, Pause while stopped cannot toggle on, and learned toggle control still starts/stops normally. Signed final delivery build and iPhone installation succeeded; physical background test result is recorded separately below.

This build is a test candidate, not submitted to App Review. Version 1.0.1 (2) remains the separately submitted localization update.

### Physical check detail

The first unlocked run passed launch measurement. In the background journey, playback state remained active after 30 seconds away, but the following Settings tap reached a tempo-entry panel and the expected Live Mode entry was absent. That full UI test failed; it is not counted as passed. The retry adds foreground animation stability and a screenshot before tapping, but was blocked by the phone locking again and canceled; that retry is still pending. Physical audible continuity, real interruption recovery and pedal hardware remain pending.

### Cassette-style setup implementation · 2026-11-03

Two tabs: connect and assign. Assignment keys directly reuse HardwareKeySurface: gray/unassigned, pressed with blinking red LED/learning, raised with green LED/assigned. Lamp and caption are centered together, and the key column is inset. Any subset of six actions can be assigned; re-learning can be canceled without losing the original mapping. Common key names and all new setup text are localized across nine languages. Reduced Motion uses a steady learning light. Preparation notes expand/collapse and collapse scrolls back to the bindings.

Connection status comes from an attached keyboard or online physical MIDI source, not merely a saved binding. Virtual MIDI endpoints do not mark the connection complete. A detected connection advances to assignment. The native picker handles Bluetooth MIDI; keyboard/page-turning pedals pair through iPhone Settings > Bluetooth. Background compatibility limitations above still apply.

Verification: 7 LiveMode logic tests and 2 UI journey tests passed on iPhone 17 Pro Max simulator, iOS 26.3. Tests cover repeated learning/cancel, preserved reassignment, tabs, preparation collapse, stopped navigation and playback continuing after settings. Chinese, English and German screenshots were inspected. Native localization validation passes for 204 strings across nine languages. Final signed Debug 1.0.2 (3) installed successfully on the connected iPhone 14 Pro at 21:19. No new physical pedal, lock-screen or call tests were run. Real app screenshots in implemented/ use an isolated DEBUG assignment fixture; they are not proof of physical pedal compatibility.

### Connection false positive correction · 1.0.2 (4)

The previous connection check was wrong: GCKeyboard.coalesced is a combined keyboard input object, not Bluetooth pedal identification. A physical/virtual keyboard can satisfy it, and an arbitrary online MIDI endpoint does not establish pedal identity or Bluetooth transport either. The connection tab no longer displays a connection check or auto-advances from these signals. Saved bindings open the assignment page for convenience but never mark a device connected. Green key LEDs mean saved assignments only. Actual HID pedal connection status remains unknown; this release does not claim to detect it.

Transient learning, held keys and MIDI parser state reset on keyboard topology changes and foreground transitions. Saved mappings survive. Offline or unreadable MIDI endpoints are excluded from routing. Messages from sources no longer in the active set are ignored. Changing MIDI source IDs cancels learning; an unchanged topology does not.

Verification: 11 logic tests + 3 UI tests passed on iPhone 17 Pro Max simulator (iOS 26.3). New cases: no saved mapping with a system keyboard available must remain on connection instructions; saved keys do not mark connection; foreground round-trip cancels learning; disconnection during reassignment preserves the old key; reconnect without key-up clears held state; disconnected/unknown MIDI sources cannot trigger actions; partial MIDI packets cannot span sessions; unchanged topology preserves learning while source replacement cancels it. Existing repeated-choice, playback, localization and interruption-model tests also passed. Screenshots inspected in Chinese and English; native strings validate across nine languages.

Debug build 1.0.2 (4) installed successfully on iPhone 14 Pro. Physical UI verification initially waited for unlock, then failed to initialize with “Authentication canceled. Canceled by user.” No physical UI assertions ran. No Bluetooth power-toggle, actual pedal reconnect, or live call/alarm claims are established by simulator tests. The previous build 3 was uploaded but was not submitted to external beta review.

Release archive 1.0.2 (4) uploaded successfully through Xcode Organizer. External group setup/review submission is still pending: Chrome interaction was repeatedly interrupted by active tab changes. No external invitation link is available yet.

External TestFlight submission completed 2026-11-03: build 1.0.2 (4), status Waiting for Review. Group Friends · Live Mode, public tester limit 10, automatically notify testers enabled. Invitation link was created and delivered privately in chat, not stored in this repository. Apple explicitly says testers cannot join until the group has an approved build. Build 3 was not added to this group.

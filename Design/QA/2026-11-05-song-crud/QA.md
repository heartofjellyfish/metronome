# Song management and polyrhythm feedback — 1.0.2 (15)

## Delivered journeys

- Setlist detail contains only song cards in its recessed container. A single raised Add song key opens a separate in-panel source page (new song, library, presets). Back/cancel creates nothing.
- Setlists: create, browse, rename, reorder songs, remove membership and confirmed deletion. Songs remain in the independent library after deleting a list.
- Library: create standalone songs, search, edit name/BPM/meter/division/sound, add to multiple lists, permanently delete with confirmation and affected-list names. A shared song edit propagates to all lists. Deleting the currently playing song stops playback and clears selection.
- Settings and configuration pages share a fixed compact transport. Stopped one-off division/meter/preset choices still return; pressing Play enables repeated live comparison without dismissing the page. Pattern-only speaker buttons removed.
- Polyrhythm: both lanes select any current instrument, persist independently, restore legacy Wood/Bell defaults. Acoustic and synthetic voice pools are separate so one lane does not choke the other. Lane sound pages use a fixed header return and clearly identify the lane.
- Normal title case for Tempo ramp. New UI strings translated into all nine existing localizations.

## Checks

- Simulator: iPhone 17 Pro, iOS 26.5, Xcode 26.5.
- Initial regression run: existing performance/navigation, shared-song membership, repeated division/pattern choices, model and rhythm tests passed. Found and fixed retained scroll offset after saving a song, and the sound-picker Back button scrolling offscreen.
- `/tmp/metronome-crud-final.xcresult`: 4 UI journeys and 7 model/audio tests passed, including CRUD/search/cancel/permanent deletion, rename/reorder/delete-list, repeated lane choices and playback across pages.
- `/tmp/metronome-crud-polish.xcresult`: final visual-state and rename/reorder/deletion journeys passed. Screenshots manually inspected. Fixed tiny text-only Edit/Rename keys, keyboard remaining after rename, and stale material color when a hardware key becomes selected.
- `/tmp/metronome-crud-release-check.xcresult`: final 7 model/audio tests plus first-play setup budget passed. First-play setup measured 0.214 seconds in the simulator; this is neither a physical-device measurement nor a first-screen launch measurement.
- Release iPhone build with development signing prepared. Device install attempt failed: CoreDevice could not locate the previously connected iPhone 14 Pro; device list reports unavailable. No successful install claimed. No TestFlight upload in this change.
- Physical launch, lock-screen, interruption, headphones and pedal hardware tests remain deferred.

## Visual decisions

- Keep the source chooser as replacement sheet content rather than an inline menu or another stacked sheet.
- Edit mode exposes reorder, edit, reuse and remove keys; ordinary browsing stays quiet. Destructive library deletion is distinct from removal from one list.
- Use one recessed cycle containing two instrument keys and pulse rows for polyrhythm. Instrument selection has its own page and the transport remains fixed.
- Remaining judgment call: stopped one-off choices close, while active comparison stays open, matching the repository's interaction contract.

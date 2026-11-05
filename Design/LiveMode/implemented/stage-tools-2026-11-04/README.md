# Stage tools — 1.0.2 (7)

Adds a synthesized STAGE CLICK, named setlists and advanced subdivisions. Keeps direct pedal assignment from build 6. This is a development build; TestFlight remains build 5 until a separate upload.

STAGE CLICK is a short 3.2 kHz pulse with a restrained second harmonic and a higher downbeat. It adds no bundled sample or launch-time decoding. The WAV examples use the same ClickVoice renderer as the app. Whether it cuts through the drummer's particular live mix still needs rehearsal feedback.

Setlists store songs with independent names/BPM and a snapshot of the current meter, sound and rhythm. Tempo ramp is disabled on adding a song. Songs can be renamed, reordered and deleted; old presets are preserved. Pedal next/previous traverses the active list without wrapping. Selecting a song while stopped returns to the instrument; during playback it applies immediately and stays open. Editing remains explicit. Deleting a song currently being edited restores the add-song action.

Division keeps four common choices visible. More rhythms reveals offbeat eighths, triplet rests, sixteenth patterns, 2:1 swing, 1–8 custom divisions with per-pulse rests, and a second 2–9 pulse polyrhythm layer. At least one primary pulse must remain. Coincident onsets sound once. Quick presets close when stopped and stay open while playing; custom editing stays open until explicitly closed. Current selections are read from the model on each change and survive closing/reopening. Rest glyphs are drawn natively to avoid unsupported font characters.

Validation on iPhone 17 Pro Max simulator, iOS 26.3:

- Existing clock/voice suite and 18 XCTest logic checks passed initially; an additional exhaustive polyrhythm/legacy-decoding check passed afterward (19 distinct logic checks in total).
- All nonempty rest masks for 1–8 divisions were checked at 20, 137 and 300 BPM. All 64 primary/secondary pairs were checked at 60, 137 and 300 BPM, including muted beats. Onsets remain within one sample of expected boundaries.
- Four existing Live Mode UI journeys and three new feature journeys passed, covering direct assignment, canceled learning, playback remaining active, consecutive choices, setlist edit/reorder/persistence, repeated sound auditions and Chinese/English screenshots. The final setlist deletion-during-edit regression also passed.
- Audio checks cover finite bounded samples, zero attack/release boundaries, higher-frequency content and compact tails at 44.1/48 kHz. All nine localization files pass syntax validation.

Physical iPhone 14 Pro, iOS 27.0.1, development build: first responsive frame averaged 0.475 s across five instrumented launches (0.411–0.638 s); first playback setup was 0.127 s. These measure Xcode launch responsiveness and audio-graph preparation, not headphone output latency. Build 7 was successfully installed; physical pedal, lock-screen, live-drum/headphone and call/alarm trials remain deferred.

Screenshots are actual simulator captures. Example setlist/song names are test data. No claim of physical pedal connectivity is made by these images.
